from brownie import LeverageGearboxYearn, accounts

from brownie_tokens import MintableForkToken


def deploy_leverage_gerarbox_yearn():
    dai_address = "0x6b175474e89094c44da98b954eedeac495271d0f"
    yearn_dai_adapter = "0x403E98b110a4DC89da963394dC8518b5f0E2D5fB"
    creditManager = "0x777e23a2acb2fcbb35f6ccf98272d03c722ba6eb"
    leverage = "200"
    leverage_gearbox_yearn = LeverageGearboxYearn.deploy(
        dai_address,
        yearn_dai_adapter,
        creditManager,
        leverage,
        {"from": accounts[0]},
    )

    decimal = 10 ** 18
    amount = 20_000 * decimal
    alice = accounts[0]

    dai = MintableForkToken(dai_address)
    dai._mint_for_testing(alice, amount)

    print("Alice depositing 20K DAI to the contract ...")
    dai.approve(leverage_gearbox_yearn, amount, {"from": alice})
    leverage_gearbox_yearn.deposit(amount, alice, {"from": alice})
    print(
        f"Contract Available Balance: {leverage_gearbox_yearn.availableAssets() / decimal}"
    )

    collateral_amount = leverage_gearbox_yearn.availableAssets() / 2
    print("Opening credit account with 3X leverage and added 10K DAI ...")
    leverage_gearbox_yearn.openAccount(collateral_amount)
    print("Depositing into Yearn ...")
    leverage_gearbox_yearn.investToYearn()

    print("Credit account opened and invested into Yearn")
    print(
        f"Contract Available DAI balance: {leverage_gearbox_yearn.availableAssets()/ decimal} "
    )
    print(f"CA address: {leverage_gearbox_yearn.getCreditAccount()}")
    print(f"CA health factor: {leverage_gearbox_yearn.getHealthFactor() / 10 ** 4}")
    print(f"CA collateral :{leverage_gearbox_yearn.getCollateralValue()/ decimal}")
    print(
        f"Current CA repay amount  :{leverage_gearbox_yearn.getRepayAmount()/ decimal}"
    )
    print(f"CA borrowed amount:{leverage_gearbox_yearn.getBorrowedAmount() / decimal}")
    print(f"CA total amount:{leverage_gearbox_yearn.getTotalValue() / decimal}")

    print("Adding 10K DAI as collateral ...")
    leverage_gearbox_yearn.addCollateral(leverage_gearbox_yearn.availableAssets())
    print(
        f"Contract CA Available DAI balance: {leverage_gearbox_yearn.availableAssets()/ decimal} "
    )
    print(
        f"Current CA health factor: {leverage_gearbox_yearn.getHealthFactor() / 10 ** 4}"
    )
    print(
        f"Current CA collateral :{leverage_gearbox_yearn.getCollateralValue()/ decimal}"
    )
    print(
        f"Current CA repay amount  :{leverage_gearbox_yearn.getRepayAmount()/ decimal}"
    )
    print(
        f"Current CA borrowed amount:{leverage_gearbox_yearn.getBorrowedAmount() / decimal}"
    )
    print(f"Current CA total amount:{leverage_gearbox_yearn.getTotalValue() / decimal}")

    print("Withdrawing from Yearn ...")
    leverage_gearbox_yearn.withdrawFromYearn()
    print("Closing Credit Account ...")
    leverage_gearbox_yearn.closeAccount()

    print(f"CA address: {leverage_gearbox_yearn.getCreditAccount()}")
    print(
        f"Contract Available DAI balance: {leverage_gearbox_yearn.availableAssets()/ decimal} "
    )


def main():
    deploy_leverage_gerarbox_yearn()
