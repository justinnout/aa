import asyncio

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.services.api.contract_class import ContractClass
from starkware.starknet.compiler.compile import compile_starknet_files
from utils.Signer import Signer
from utils.TransactionSender import TransactionSender

def compile(path: str) -> ContractClass:
    contract_cls = compile_starknet_files([path], debug_info=True)
    return contract_cls

async def main():
    signer = Signer(1)

    starknet = await Starknet.empty()

    #####
    # Setup
    #####
    print("Deploying Dapp to local starknet...")
    dapp = await starknet.deploy(
        contract_class=compile("contracts/test/TestDapp.cairo"),
        constructor_calldata=[],
    )

    print("Deploying MagicAccount to local starknet...")
    account = await starknet.deploy(
        contract_class=compile('contracts/MagicAccount.cairo'),
        constructor_calldata=[]
    )

    print("Initializing Magic Account...")
    await account.initialize(signer.public_key).execute()
    print(f"\t{account.contract_address} initialized")


    #####
    # Single call demo
    #####
    print("\n\n\nCall Dapp and check the number set for our account...")
    print(f"\tNumber: [{(await dapp.get_number(account.contract_address).call()).result.number}]")

    print("Call Dapp to set a new number...")
    sender = TransactionSender(account)
    num = input("\tNew number: ")

    await sender.send_transaction([(dapp.contract_address, 'set_number', [int(num)])], [signer])
    print("\tNew number set!")

    print("Call Dapp and check the number set for our account...")
    print(f"\tNumber: [{(await dapp.get_number(account.contract_address).call()).result.number}]")

    #####
    # Multi call demo
    #####
    print("\n\n\nTesting multi-call for set_number and increase_number operations...")
    print("Call Dapp and get current number set for our account...")
    print(f"\tCurrent number: [{(await dapp.get_number(account.contract_address).call()).result.number}]")
    set_num = input("\tSet number to: ")
    inc_num = input("\tIncrease number by: ")
    await sender.send_transaction([(dapp.contract_address, 'set_number', [int(set_num)]), (dapp.contract_address, 'increase_number', [int(inc_num)])], [signer])
    print("\tMulti-call operations sent!")
    
    print("Call Dapp and get current number set for our account...")
    print(f"\tNumber: [{(await dapp.get_number(account.contract_address).call()).result.number}]")

asyncio.run(main())
