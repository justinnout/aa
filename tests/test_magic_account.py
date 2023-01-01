import pytest
import asyncio

from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer
from utils.utilities import cached_contract, compile, assert_revert, str_to_felt
from utils.TransactionSender import TransactionSender

signer = Signer(1)
new_signer = Signer(4)
wrong_signer = Signer(7)

VERSION = str_to_felt('0.1.0')
NAME = str_to_felt('MagicAccount')

@pytest.fixture(scope='module')
def account_cls() -> ContractClass:
    return compile('contracts/MagicAccount.cairo')

@pytest.fixture(scope='module')
def test_dapp_cls() -> ContractClass:
    return compile("contracts/test/TestDapp.cairo")

@pytest.fixture(scope='module')
async def starknet():
    return await Starknet.empty()

@pytest.fixture(scope='function')
async def contract_init(account_cls: ContractClass, test_dapp_cls: ContractClass):
    starknet = await Starknet.empty()

    account = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[]
    )

    await account.initialize(signer.public_key).execute()

    dapp = await starknet.deploy(
        contract_class=test_dapp_cls,
        constructor_calldata=[],
    )

    return starknet.state, account, dapp

@pytest.fixture
async def contract_factory(account_cls: ContractClass, test_dapp_cls: ContractClass, contract_init):
    state, account, dapp = await contract_init
    _state = state.copy()

    account = cached_contract(_state, account_cls, account)
    dapp = cached_contract(_state, test_dapp_cls, dapp)

    return account, dapp

@pytest.mark.asyncio
async def test_initializer(contract_factory):
    account, _ = await contract_factory
    
    # should be configured correctly
    assert (await account.getSigner().call()).result.signer == (signer.public_key)
    assert (await account.getVersion().call()).result.version == VERSION
    assert (await account.getName().call()).result.name == NAME

    # should throw when calling initialize twice
    await assert_revert(
         account.initialize(signer.public_key).execute(),
         "magic: already initialized"
     )

@pytest.mark.asyncio
async def test_declare(contract_factory):
    account, _ = await contract_factory
    sender = TransactionSender(account)

    test_cls = compile("contracts/test/StructHash.cairo")

    # should revert with wrong signer
    await assert_revert(
        sender.declare_class(test_cls, [wrong_signer]),
        "magic: signer signature invalid"
    )

    tx_exec_info = await sender.declare_class(test_cls, [signer])

@pytest.mark.asyncio
async def test_call_dapp(contract_factory):
    account, dapp = await contract_factory
    sender = TransactionSender(account)

    # should call the dapp
    assert (await dapp.get_number(account.contract_address).call()).result.number == 0
    await sender.send_transaction([(dapp.contract_address, 'set_number', [47])], [signer])
    assert (await dapp.get_number(account.contract_address).call()).result.number == 47

@pytest.mark.asyncio
async def test_multicall(contract_factory):
    account, dapp = await contract_factory
    sender = TransactionSender(account)

    # should call the dapp
    assert (await dapp.get_number(account.contract_address).call()).result.number == 0
    await sender.send_transaction([(dapp.contract_address, 'set_number', [47]), (dapp.contract_address, 'increase_number', [10])], [signer])
    assert (await dapp.get_number(account.contract_address).call()).result.number == 57
