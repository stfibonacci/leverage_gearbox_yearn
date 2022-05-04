// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "../interfaces/tokens/ERC20.sol";
import {ERC4626} from "../interfaces/mixins/ERC4626.sol";

import {IYVault} from "../interfaces/gearbox/IYVault.sol";
import {ICreditAccount} from "../interfaces/gearbox/ICreditAccount.sol";
import {ICreditFilter} from "../interfaces/gearbox/ICreditFilter.sol";
import {ICreditManager} from "../interfaces/gearbox/ICreditManager.sol";

contract LeverageGearboxYearn is ERC4626, Ownable {
    address public creditAccount;
    ICreditManager public creditManager;
    ICreditFilter public creditFilter;
    IYVault public yearnAdapter;
    uint256 public leverage;

    constructor(
        ERC20 _asset,
        address _yearnAdapter,
        address _creditManager,
        uint256 _leverage
    ) ERC4626(_asset, " Leverage Gearbox Yearn DAI", "lgyDAI") {
        require(address(_asset) != address(0), "ZERO_ADDRESS");
        require(_yearnAdapter != address(0), "ZERO_ADDRESS");
        require(_creditManager != address(0), "ZERO_ADDRESS");
        require(_leverage > 0 && _leverage <= 300, " 300 >= LEVERAGE > 0");

        yearnAdapter = IYVault(_yearnAdapter);
        creditManager = ICreditManager(_creditManager);
        creditFilter = ICreditFilter(creditManager.creditFilter());
        leverage = _leverage;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner(), "only authorized");
        _;
    }

    function openAccount(uint256 assets) external onlyAuthorized {
        require(assets != 0, "ZERO_ASSETS");
        asset.approve(address(creditManager), type(uint256).max);
        creditManager.openCreditAccount(assets, address(this), leverage, 0);
        creditAccount = creditManager.getCreditAccountOrRevert(address(this));
    }

    function investToYearn() external onlyAuthorized {
        uint256 _assets = asset.balanceOf(creditAccount);
        require(_assets != 0, "ZERO_ASSETS");
        yearnAdapter.deposit(_assets);
    }

    function withdrawFromYearn() external onlyAuthorized {
        uint256 yShares = yearnAdapter.balanceOf(creditAccount);
        require(yShares != 0, "ZERO_ySHARES");
        yearnAdapter.withdraw(yShares);
    }

    function addCollateral(uint256 assets) external onlyAuthorized {
        require(assets != 0, "ZERO_ASSETS");
        creditManager.addCollateral(address(this), address(asset), assets);
    }

    function closeAccount() external onlyAuthorized {
        uint256 yShares = yearnAdapter.balanceOf(creditAccount);
        if (yShares != 0) yearnAdapter.withdraw(yShares);

        creditManager.repayCreditAccount(address(this));
    }

    function getCreditAccount() public view returns (address) {
        return creditManager.creditAccounts(address(this));
    }

    function getHealthFactor() public view returns (uint256) {
        return
            creditFilter.calcCreditAccountHealthFactor(address(creditAccount));
    }

    function getBorrowedAmount() public view returns (uint256) {
        return ICreditAccount(creditAccount).borrowedAmount();
    }

    function getTotalValue() public view returns (uint256) {
        return creditFilter.calcTotalValue(address(creditAccount));
    }

    function getCollateralValue() public view returns (uint256) {
        if (creditManager.hasOpenedCreditAccount(address(this))) {
            uint256 tV = getTotalValue();
            uint256 tB = getBorrowedAmount();
            uint256 tC = tV - tB;
            return tC;
        } else {
            return 0;
        }
    }

    function availableAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function totalAssets() public view override returns (uint256) {
        return availableAssets() + getCollateralValue();
    }
}
