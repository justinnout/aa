%lang starknet

// Adapted from Argent Labs

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_nn
from starkware.starknet.common.syscalls import (
    call_contract,
    get_caller_address,
)
from starkware.cairo.common.bool import TRUE

from contracts.utils.calls import CallArray

const TRANSACTION_VERSION = 1;
const QUERY_VERSION = 2**128 + TRANSACTION_VERSION;

/////////////////////
// STORAGE VARIABLES
/////////////////////

@storage_var
func _signer() -> (res: felt) {
}

/////////////////////
// INTERNAL FUNCTIONS
/////////////////////

func assert_initialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (signer) = _signer.read();
    with_attr error_message("magic: account not initialized") {
        assert_not_zero(signer);
    }
    return ();
}

func assert_non_reentrant{syscall_ptr: felt*}() -> () {
    let (caller) = get_caller_address();
    with_attr error_message("magic: no reentrant call") {
        assert caller = 0;
    }
    return ();
}

func assert_correct_tx_version{syscall_ptr: felt*}(tx_version: felt) -> () {
    with_attr error_message("magic: invalid tx version") {
        assert (tx_version - TRANSACTION_VERSION) * (tx_version - QUERY_VERSION) = 0;
    }
    return ();
}

func assert_no_self_call(self: felt, call_array_len: felt, call_array: CallArray*) {
    if (call_array_len == 0) {
        return ();
    }
    assert_not_zero(call_array[0].to - self);
    assert_no_self_call(self, call_array_len - 1, call_array + CallArray.SIZE);
    return ();
}

namespace MagicModel {

    /////////////////////
    // WRITE FUNCTIONS
    /////////////////////

    func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        signer: felt
    ) {
        // check that we are not already initialized
        let (current_signer) = _signer.read();
        with_attr error_message("magic: already initialized") {
            assert current_signer = 0;
        }
        // check that the target signer is not zero
        with_attr error_message("magic: signer cannot be null") {
            assert_not_zero(signer);
        }
        // initialize the contract
        _signer.write(signer);
        return ();
    }

    /////////////////////
    // VIEW FUNCTIONS
    /////////////////////

    func is_valid_signature{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
    }(hash: felt, sig_len: felt, sig: felt*) -> (is_valid: felt) {
        alloc_locals;

        let (is_signer_sig_valid) = validate_signer_signature(hash, sig_len, sig);

        return (is_valid=is_signer_sig_valid);
    }

    func validate_signer_signature{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
    }(message: felt, signatures_len: felt, signatures: felt*) -> (is_valid: felt) {
        with_attr error_message("magic: signer signature invalid") {
            assert_nn(signatures_len - 2);
            let (signer) = _signer.read();
            verify_ecdsa_signature(
                message=message, public_key=signer, signature_r=signatures[0], signature_s=signatures[1]
            );
        }
        return (is_valid=TRUE);
    }

    func get_signer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        signer: felt
    ) {
        let (res) = _signer.read();
        return (signer=res);
    }
}