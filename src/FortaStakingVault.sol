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

    mapping(uint256 => uint256) public assetsPerSubject;
    uint256[] public subjects;

    IFortaStaking private immutable _staking;
    IERC20 private immutable _token;
    address private immutable _receiverImplementation;
    uint256 private _totalAssets;

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

    function _updatePoolsAssets() private {
        for (uint256 i = 0; i < subjects.length; ++i) {
            _updatePoolAssets(subjects[i]);
        }
    }

    function _updatePoolAssets(uint256 subject) private {
        uint256 activeId = FortaStakingUtils.subjectToActive(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        uint256 inactiveId = FortaStakingUtils.activeToInactive(activeId);

        uint256 assets = _staking.activeSharesToStake(activeId, _staking.balanceOf(address(this), activeId))
            + _staking.inactiveSharesToStake(inactiveId, _staking.balanceOf(address(this), inactiveId));
        
        if(assetsPerSubject[subject] != assets) {
            _totalAssets = _totalAssets - assetsPerSubject[subject] + assets;
            assetsPerSubject[subject] = assets;
        }
    }

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    //// Operator functions ////

    function _validateIsOperator() private view {
        if (!hasRole(OPERATOR_ROLE, msg.sender)) {
            revert NotOperator();
        }
    }

    function delegate(uint256 subject, uint256 assets) public {
        _validateIsOperator();

        if (assetsPerSubject[subject] == 0) {
            subjects.push(subject);
        }
        _token.approve(address(_staking), assets);
        uint256 shares = _staking.deposit(DELEGATOR_SCANNER_POOL_SUBJECT, subject, assets);
        assetsPerSubject[subject] += shares;
    }

    function initiateUndelegate(uint256 subject, uint256 shares) public returns (uint64) {
        _validateIsOperator();

        uint64 lock = IFortaStaking(_staking).initiateWithdrawal(DELEGATOR_SCANNER_POOL_SUBJECT, subject, shares);
        // here we can count pending withdrawals shares
        return lock;
    }

    function undelegate(uint256 subject) public {
        _validateIsOperator();
        _updatePoolAssets(subject);

        uint256 beforeWithdrawBalance = _token.balanceOf(address(this));
        IFortaStaking(_staking).withdraw(DELEGATOR_SCANNER_POOL_SUBJECT, subject);
        uint256 afterWithdrawBalance = _token.balanceOf(address(this));

        assetsPerSubject[subject] -= beforeWithdrawBalance - afterWithdrawBalance;

        if (assetsPerSubject[subject] == 0) {
            for (uint256 i = 0; i < subjects.length; i++) {
                if (subjects[i] == subject) {
                    subjects[i] = subjects[subjects.length - 1];
                    subjects.pop();
                }
            }
        }
    }

    //// User operations ////

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        _updatePoolsAssets();

        uint256 beforeDepositBalance = _token.balanceOf(address(this));
        uint256 shares = super.deposit(assets, receiver);
        uint256 afterDepositBalance = _token.balanceOf(address(this));

        _totalAssets += afterDepositBalance - beforeDepositBalance;

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        _updatePoolsAssets();

        if (msg.sender != owner) {
            // caller needs to be allowed
            _spendAllowance(owner, msg.sender, shares);
        }
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
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
                    FortaStakingUtils.subjectToActive(DELEGATOR_SCANNER_POOL_SUBJECT, subject),
                    sharesToUndelegateInSubject,
                    ""
                );
                _updatePoolAssets(subject);
                tempSharesToUndelegate[newUndelegations] = sharesToUndelegateInSubject;
                tempSubjectsToUndelegateFrom[newUndelegations] = subject;
                ++newUndelegations;
            }
        }
        uint256[] memory sharesToUndelegate = new uint256[](newUndelegations);
        uint256[] memory subjectsToUndelegateFrom = new uint256[](newUndelegations);
        for (uint256 i = 0; i < newUndelegations; ++i) {
            sharesToUndelegate[i] = tempSharesToUndelegate[i];
            subjectsToUndelegateFrom[i] = tempSubjectsToUndelegateFrom[i];
        }
        redemptionReceiver.addUndelegations(subjectsToUndelegateFrom, sharesToUndelegate);

        // send portion of assets in the pool
        uint256 vaultBalance = _token.balanceOf(address(this));
        uint256 vaultBalanceToRedeem = Math.mulDiv(shares, vaultBalance, totalSupply());

        _token.transfer(receiver, vaultBalanceToRedeem);
        _totalAssets -= vaultBalanceToRedeem;
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
