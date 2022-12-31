%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import (
    get_tx_info,
    library_call,
    get_contract_address,
)

from contracts.utils.calls import (
    CallArray,
    execute_multicall,
)

from contracts.library import (
    MagicModel,
    assert_correct_tx_version,
    assert_non_reentrant,
    assert_initialized,
    assert_no_self_call,
)

//
// @title MagicAccount
// @author justinnout
// @notice Main account for Magic on StarkNet
//

/////////////////////
// CONSTANTS
/////////////////////

const NAME = 'MagicAccount';
const VERSION = '0.1.0';

/////////////////////
// EVENTS
/////////////////////

@event
func account_created(account: felt, key: felt) {
}

@event
func transaction_executed(hash: felt, response_len: felt, response: felt*) {
}

/////////////////////
// ACCOUNT INTERFACE
/////////////////////

@external
func __validate__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    range_check_ptr
} (
    call_array_len: felt,
    call_array: CallArray*,
    calldata_len: felt,
    calldata: felt*
) {
    alloc_locals;

    // make sure the account is initialized
    assert_initialized();

    // get the tx info
    let (tx_info) = get_tx_info();

    if (call_array_len == 1) {
        if (call_array[0].to == tx_info.account_contract_address) {
            tempvar signer_condition = (call_array[0].selector);
            if (signer_condition == 0) {
                // validate signer signature
                MagicModel.validate_signer_signature(
                    tx_info.transaction_hash, tx_info.signature_len, tx_info.signature
                );
                return ();
            }
        }
    } else {
        // make sure no call is to the account
        assert_no_self_call(tx_info.account_contract_address, call_array_len, call_array);
    }

    // validate signer
    MagicModel.validate_signer_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}


@external
@raw_output
func __execute__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    range_check_ptr
} (
    call_array_len: felt,
    call_array: CallArray*,
    calldata_len: felt,
    calldata: felt*
) -> (
    retdata_size: felt, retdata: felt*
) {
    alloc_locals;

    let (tx_info) = get_tx_info();

    // block transaction with version != 1 or QUERY
    assert_correct_tx_version(tx_info.version);
    
    // no reentrant call to prevent signature reutilization
    assert_non_reentrant();

    // execute calls
    let (retdata_len, retdata) = execute_multicall(call_array_len, call_array, calldata);

    // emit event
    transaction_executed.emit(
        hash=tx_info.transaction_hash, response_len=retdata_len, response=retdata
    );
    return (retdata_size=retdata_len, retdata=retdata);
}

@external
func __validate_declare__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    range_check_ptr
} (
    class_hash: felt
) {
    alloc_locals;
    // get the tx info
    let (tx_info) = get_tx_info();
    // validate signatures
    MagicModel.validate_signer_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}


@raw_input
@external
func __validate_deploy__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    range_check_ptr
} (selector: felt, calldata_size: felt, calldata: felt*) {
    alloc_locals;
    // get the tx info
    let (tx_info) = get_tx_info();
    // validate signatures
    MagicModel.validate_signer_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}

/////////////////////
// EXTERNAL FUNCTIONS
/////////////////////

// @dev Initializes the account with the signer.
// Must be called immediately after the account is deployed.
// @param signer The signer public key
@external
func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    signer: felt
) {
    MagicModel.initialize(signer);
    let (self) = get_contract_address();
    return ();
}

/////////////////////
// VIEW FUNCTIONS
/////////////////////

// @dev Gets the current signer
// @return signer The public key of the signer
@view
func getSigner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    signer: felt
) {
    let (res) = MagicModel.get_signer();
    return (signer=res);
}

// @dev Gets the version of the account implementation
// @return version The current version as a short string
@view
func getVersion() -> (version: felt) {
    return (version=VERSION);
}

// @dev Gets the name of the account implementation
// @return name The name as a short string
@view
func getName() -> (name: felt) {
    return (name=NAME);
}