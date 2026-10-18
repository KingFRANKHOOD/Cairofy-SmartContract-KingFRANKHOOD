use starknet::ContractAddress;
use starknet::contract_address_const;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use smart_contract::interfaces::iartist::{
    IArtistDispatcher, IArtistDispatcherTrait, IArtistSafeDispatcher, IArtistSafeDispatcherTrait,
};

fn deploy_artist_contract() -> ContractAddress {
    let contract = declare("ArtistComponent").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn artist_owner() -> ContractAddress {
    contract_address_const::<0x123>()
}

fn other_owner() -> ContractAddress {
    contract_address_const::<0x456>()
}

#[test]
fn test_register_artist() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    assert(artist_id == 1, 'Wrong artist id');

    let artist = dispatcher.get_artist(artist_id);
    assert(artist.name == 'Lil Cairo', 'Wrong name');
    assert(artist.owner == artist_owner(), 'Wrong owner');
    assert(artist.total_streams == 0, 'Streams should start at 0');
    assert(artist.pending_rewards == 0, 'Rewards should start at 0');
    assert(artist.song_count == 0, 'Song count should start at 0');
    assert(artist.exists, 'Artist should exist');
    assert(dispatcher.is_registered(artist_id), 'Should be registered');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_register_artist_twice() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    dispatcher.register_artist('Lil Cairo');

    let safe_dispatcher = IArtistSafeDispatcher {
        contract_address,
    };
    match safe_dispatcher.register_artist('Lil Cairo Again') {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Artist already registered', *panic_data.at(0));
        },
    };
}

#[test]
fn test_update_artist_profile() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');
    dispatcher.update_artist_profile(artist_id, 'Lil Cairo II');

    let artist = dispatcher.get_artist(artist_id);
    assert(artist.name == 'Lil Cairo II', 'Name was not updated');
}

#[test]
#[feature("safe_dispatcher")]
fn test_only_owner_can_update_profile() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    start_cheat_caller_address(contract_address, other_owner());
    let safe_dispatcher = IArtistSafeDispatcher {
        contract_address,
    };
    match safe_dispatcher.update_artist_profile(artist_id, 'Hacked Name') {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
        },
    };
}

#[test]
fn test_record_streams_and_claim_rewards() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    // Incentive Reward = Count / Guess Value (guess value is 100 internally).
    dispatcher.record_streams(artist_id, 250);

    let artist = dispatcher.get_artist(artist_id);
    assert(artist.total_streams == 250, 'Wrong total streams');
    assert(dispatcher.get_pending_rewards(artist_id) == 2, 'Wrong pending rewards');

    let claimed = dispatcher.claim_rewards(artist_id);
    assert(claimed == 2, 'Wrong claimed amount');
    assert(dispatcher.get_pending_rewards(artist_id) == 0, 'Rewards should reset');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_claim_with_no_rewards() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    let safe_dispatcher = IArtistSafeDispatcher {
        contract_address,
    };
    match safe_dispatcher.claim_rewards(artist_id) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'No rewards to claim', *panic_data.at(0));
        },
    };
}

#[test]
fn test_increment_song_count() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    dispatcher.increment_song_count(artist_id);
    dispatcher.increment_song_count(artist_id);

    let artist = dispatcher.get_artist(artist_id);
    assert(artist.song_count == 2, 'Wrong song count');
}

#[test]
fn test_get_artist_id_by_owner() {
    let contract_address = deploy_artist_contract();
    let dispatcher = IArtistDispatcher { contract_address };

    start_cheat_caller_address(contract_address, artist_owner());
    let artist_id = dispatcher.register_artist('Lil Cairo');

    assert(
        dispatcher.get_artist_id_by_owner(artist_owner()) == artist_id, 'Wrong artist id lookup',
    );
    assert(dispatcher.get_artist_id_by_owner(other_owner()) == 0, 'Should be unregistered');
}
