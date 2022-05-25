// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "../interfaces/tokens/ERC20.sol";
import {ERC4626} from "../interfaces/mixins/ERC4626.sol";

import {IUniswapV2} from "../interfaces/gearbox/IUniswapV2.sol";
import {ICreditAccount} from "../interfaces/gearbox/ICreditAccount.sol";
import {ICreditFilter} from "../interfaces/gearbox/ICreditFilter.sol";
import {ICreditManager} from "../interfaces/gearbox/ICreditManager.sol";

contract GearboxTokenLongV2 is ERC4626, Ownable {
    address public creditAccount;
    ICreditManager public creditManager; // ICreditManager(0x777e23a2acb2fcbb35f6ccf98272d03c722ba6eb);
    ICreditFilter public creditFilter;
    uint256 public leverage; // 300
    IUniswapV2 public immutable uniswapAdapter; //  IUniswapV2(0xEdBf8F73908c86a89f4D42344c8e01b82fE4Aaa6)
    ERC20 public constant WETH =
        ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ERC20 public immutable token;
    uint256 public constant minAmount = 1000000000000000000000;
    uint256 public constant maxAmount = 125000000000000000000000;
    address public manager;

    constructor(
        ERC20 _asset,
        ERC20 _token,
        address _uniswapAdapter,
        address _creditManager,
        uint256 _leverage
    ) ERC4626(_asset, " Gearbox Eth Long", "gelDAI") {
        require(address(_asset) != address(0), "ZERO_ADDRESS");
        require(_uniswapAdapter != address(0), "ZERO_ADDRESS");
        require(_creditManager != address(0), "ZERO_ADDRESS");

        uniswapAdapter = IUniswapV2(_uniswapAdapter);
        creditManager = ICreditManager(_creditManager);
        require(
            _leverage > 0 && _leverage <= creditManager.maxLeverageFactor(),
            " LEVERAGE_NOT_IN_RANGE"
        );
        creditFilter = ICreditFilter(creditManager.creditFilter());
        creditFilter.revertIfTokenNotAllowed(address(_token));

        leverage = _leverage;
        token = _token;
        manager = msg.sender;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner(), "only authorized");
        _;
    }

    function afterDeposit(uint256 assets, uint256) internal override {
        if (creditManager.hasOpenedCreditAccount(address(this))) {
            _addCollateral(assets);
            _borrowMore(assets);
        } else {
            _openAccount(assets);
        }
        _swap(address(asset), address(token), asset.balanceOf(creditAccount));
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        if (creditAccount != address(0)) _closeAccount();

        uint256 remainingBalance = availableAssets() - assets;

        if (remainingBalance > minAmount)
            afterDeposit(remainingBalance, shares);
    }

    function openAccount(uint256 assets) external onlyAuthorized {
        _openAccount(assets);
    }

    function closeAccount() external onlyAuthorized {
        _closeAccount();
    }

    function swapAllForAsset() external onlyAuthorized {
        uint256 _amountIn = getTokenBalance();

        _swap(address(token), address(asset), _amountIn);
    }

    function swapAllForToken() external onlyAuthorized {
        uint256 _amountIn = getAssetBalance();
        _swap(address(asset), address(token), _amountIn);
    }

    function addCollateral(uint256 assets) external onlyAuthorized {
        _addCollateral(assets);
    }

    function borrowMore(uint256 assets) external onlyAuthorized {
        _borrowMore(assets);
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
        if (address(creditAccount) != address(0)) {
            uint256 tV = getTotalValue();
            uint256 tD = getRepayAmount();
            uint256 tC = tV - tD;
            //slippage 1%
            return (tC * 99) / 100;
        } else {
            return 0;
        }
    }

    function getRepayAmount() public view returns (uint256) {
        return creditManager.calcRepayAmount(address(this), false);
    }

    function getTokenBalance() public view returns (uint256) {
        return token.balanceOf(creditAccount);
    }

    function getAssetBalance() public view returns (uint256) {
        return asset.balanceOf(address(creditAccount));
    }

    function _openAccount(uint256 assets) internal {
        require(
            assets >= minAmount && assets <= maxAmount,
            "AMOUNT_NOT_IN_RANGE"
        );
        asset.approve(address(creditManager), type(uint256).max);
        creditManager.openCreditAccount(assets, address(this), leverage, 0);
        creditAccount = creditManager.getCreditAccountOrRevert(address(this));
    }

    function _closeAccount() internal {
        uint256 _tokenBalance = getTokenBalance();
        if (_tokenBalance != 0)
            _swap(address(token), address(asset), _tokenBalance);

        creditManager.repayCreditAccount(address(this));
    }

    function _addCollateral(uint256 assets) internal {
        require(assets != 0, "ZERO_ASSETS");
        creditManager.addCollateral(address(this), address(asset), assets);
    }

    function _borrowMore(uint256 assets)
        internal
        returns (uint256 borrowAmount)
    {
        borrowAmount = (leverage * assets) / 100;
        creditManager.increaseBorrowedAmount(borrowAmount);
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
        address[] memory path;

        if (tokenIn == address(WETH) || tokenOut == address(WETH)) {
            path = new address[](2);
            path[0] = address(tokenIn);
            path[1] = address(tokenOut);
        } else {
            path = new address[](3);
            path[0] = address(tokenIn);
            path[1] = address(WETH);
            path[2] = address(tokenOut);
        }

        // uint256 _amountOutMin = uniswapAdapter.getAmountsOut(amountIn, path)[
        //     2
        // ];

        uniswapAdapter.swapExactTokensForTokens(
            amountIn,
            0, //uint256(0)
            path,
            address(creditAccount),
            block.timestamp + 120
        );
    }

    function availableAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function totalAssets() public view override returns (uint256) {
        return availableAssets() + getCollateralValue();
    }
}
