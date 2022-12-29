# aa
account abstraction on starknet

## background

StarkNet Alpha 0.10.0 includes native account abstraction implementation. This version introduces changes inspired by EIP-4337.

## quickstart to accounts on starknet

The general workflow is:
1. Account contract is deployed to StarkNet.
2. Signed transactions can now be sent to the Account contract which validates and executes them.

In Python, this would look as follows:
```
from starkware.starknet.testing.starknet import Starknet
from utils import get_contract_class
from signers import MockSigner

signer = MockSigner(123456789987654321)

starknet = await Starknet.empty()

# 1. Deploy Account
account = await starknet.deploy(
    get_contract_class("Account"),
    constructor_calldata=[signer.public_key]
)

# 2. Send transaction through Account
await signer.send_transaction(account, some_contract_address, 'some_function', [some_parameter])
```

### Account entrypoints

Account contracts have only three entry points for all user interactions:

`__validate_declare__` validates the declaration signature prior to the declaration. As of Cairo v0.10.0, contract classes should be declared from an Account contract.

`__validate__` verifies the transaction signature before executing the transaction with `__execute__`.

`__execute__` acts as the state-changing entry point for all user interaction with any contract, including managing the account contract itself. That’s why if you want to change the public key controlling the Account, you would send a transaction targeting the very Account contract:
```
await signer.send_transaction(
    account,
    account.contract_address,
    'set_public_key',
    [NEW_KEY]
)
```

## development

### compile the contracts

```
make build
```

### test the contracts

```
make test
```