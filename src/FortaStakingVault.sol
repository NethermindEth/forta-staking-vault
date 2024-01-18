// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IFortaStaking.sol";
import "./utils/FortaStakingUtils.sol";
import "./RedemptionReceiver.sol";

contract FortaStakingVault is AccessControl, ERC4626, ERC1155Holder {
    using Address for address;
    using Clones for address;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(uint256 => uint256) public stakes; // todo: should it be public ?
    uint256[] public subjects;

    IFortaStaking private immutable _staking;
    IERC20 private immutable _token;
    address private immutable _receiverImplementation;

    error NotOperator();

    constructor(address _asset, address _fortaStaking, address _redemptionReceiverImplementation)
        ERC20("FORT Staking Vault", "vFORT")
        ERC4626(IERC20(_asset))
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _staking = IFortaStaking(_fortaStaking);
        _token = IERC20(_asset);
        _receiverImplementation = _redemptionReceiverImplementation;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Holder, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    //// Operator functions ////

    function _validateIsOperator() private view {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert NotOperator();
        }
    }

    function delegate(uint256 subject, uint256 assets) public {
        _validateIsOperator();
        if (stakes[subject] == 0) {
            subjects.push(subject);
        }
        _token.approve(address(_staking), assets);
        uint256 shares = _staking.deposit(DELEGATOR_SCANNER_POOL_SUBJECT, subject, assets);
        stakes[subject] += shares;
    }

    function initiateUndelegate(uint256 subject, uint256 amount) public returns (uint64) {
        _validateIsOperator();
        uint64 lock = IFortaStaking(_staking).initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, subject, amount);
        // here we can count pending withdrawals shares
        return lock;
    }

    function undelegate(uint256 subject) public {
        _validateIsOperator();
        uint256 withdrawn = IFortaStaking(_staking).withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        assert(stakes[subject] >= withdrawn);
        stakes[subject] -= withdrawn;
        if (stakes[subject] == 0) {
            for (uint i = 0; i < subjects.length; i++) {
                if (subjects[i] == subject) {
                    subjects[i] = subjects[subjects.length - 1];
                    subjects.pop();
                }
            }
        }
    }

    //// User operations ////

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(msg.sender, shares, maxShares);
        }
        if (msg.sender != owner) {
            // caller needs to be allowed
            _spendAllowance(owner, msg.sender, shares);
        }

        // user withdraw contract
        RedemptionReceiver redemptionReceiver = RedemptionReceiver(createAndGetRedemptionReceiver(owner));

        uint256 newUndelegations;
        uint256[] memory tempSharesToUndelegate = new uint256[](subjects.length);
        uint256[] memory tempSubjectsToUndelegateFrom = new uint256[](subjects.length);

        for (uint256 i = 0; i < subjects.length; ++i) {
            uint256 subject = subjects[i];
            uint256 subjectShares = _staking.sharesOf(DELEGATOR_SCANNER_POOL_SUBJECT, subject, address(this));
            uint256 sharesToUndelegateInSubject = Math.mulDiv(shares, subjectShares, totalSupply());
            if (sharesToUndelegateInSubject != 0) {
                _staking.safeTransferFrom(
                    address(this),
                    address(redemptionReceiver),
                    _staking.activeStakeFor(DELEGATOR_SCANNER_POOL_SUBJECT, subject),
                    sharesToUndelegateInSubject,
                    ""
                );
                tempSharesToUndelegate[newUndelegations] = subject;
                tempSubjectsToUndelegateFrom[newUndelegations] = sharesToUndelegateInSubject;
                ++newUndelegations;
            }
        }
        uint256[] memory sharesToUndelegate = new uint256[](newUndelegations);
        uint256[] memory subjectsToUndelegateFrom = new uint256[](newUndelegations);
        for (uint256 i = 0; i < newUndelegations; ++i) {
            sharesToUndelegate[i] = tempSharesToUndelegate[i];
            subjectsToUndelegateFrom[i] = subjectsToUndelegateFrom[i];
        }
        redemptionReceiver.addUndelegations(subjectsToUndelegateFrom, sharesToUndelegate);

        // send portion of assets in the pool
        uint256 vaultBalance = _token.balanceOf(address(this));
        uint256 vaultBalanceToRedeem = Math.mulDiv(shares, vaultBalance, totalSupply());

        _token.transfer(receiver, vaultBalanceToRedeem);
        _burn(owner, shares);

        // TODO: Deal with inactive assets

        return vaultBalanceToRedeem;
    }

    function claimReedem(address receiver) public returns (uint256) {
        RedemptionReceiver redemptionReceiver = RedemptionReceiver(getRedemptionReceiver(msg.sender));

        return redemptionReceiver.claim(receiver);
    }

    function getSalt(address user) private pure returns (bytes32) {
        return keccak256(abi.encode(user));
    }

    function getRedemptionReceiver(address user) public view returns (address) {
        return _receiverImplementation.predictDeterministicAddress(getSalt(user), address(this));
    }

    function createAndGetRedemptionReceiver(address user) private returns (address) {
        address receiver = getRedemptionReceiver(user);
        if (receiver.code.length == 0) {
            // create and initialize a new contract
            _receiverImplementation.cloneDeterministic(getSalt(user));
            RedemptionReceiver(receiver).initialize(address(this), _staking);
        }
        return receiver;
    }
}
