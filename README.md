# MultipleSign-Contract

## Deploy Multisig Contract on Remix

Multi-Signatute Wallets allow a wallet to be controlled by more than 1 owner. In order to approve transactions a thrsehold number of signatures are required. E.g 2/3 Multisig Wallet -> if there are 3 owners, at least 2 have to apprive. A popular, secure and trusted [Multi-Sig Wallet]

You can add more Owner in accounts for make network big

### Deploy Multi-Sig Contract Using Remix

- when we deploy this contract we need to provide minAmount which tell if someone join the As Owner for voting he have to provide that min Amount as contributions

- user can applyForOwner owner and existing owner will accept or reject it request by voting
- Voteforowner will check if number of count reached to numConfirmationsRequired equal to numConfirmations it will approve otherwise reject and return the amount
- submitTransaction user can apply for withdraw amount
- confirmTransaction allow to with draw amount
- executeTransaction if numConfirmationsRequired confirm the transaction the move the amount otherwise wait for other to approve
- revokeConfirmation you conformation
