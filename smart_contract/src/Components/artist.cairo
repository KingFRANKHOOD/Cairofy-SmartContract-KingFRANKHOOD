#[starknet::component]
pub mod ArtistComponent {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess,
        StorageMapWriteAccess, Map,
    };
    use crate::interfaces::iartist::{Artist, IArtist};

    #[storage]
    pub struct Storage {
        artists: Map<felt252, Artist>,
        artist_by_address: Map<ContractAddress, felt252>,
        artist_count: felt252,
        incentive_guess_value: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ArtistRegistered: ArtistRegistered,
        RewardsClaimed: RewardsClaimed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtistRegistered {
        pub artist_id: felt252,
        pub name: felt252,
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsClaimed {
        pub artist_id: felt252,
        pub amount: u256,
    }

    #[embeddable_as(ArtistImpl)]
    impl ArtistComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IArtist<ComponentState<TContractState>> {
        fn register_artist(ref self: ComponentState<TContractState>, name: felt252) -> felt252 {
            let caller = get_caller_address();
            let existing_id = self.artist_by_address.read(caller);
            assert(existing_id == 0, 'Artist already registered');

            let count: felt252 = self.artist_count.read();
            let new_id: felt252 = count + 1;

            let artist = Artist {
                id: new_id,
                name,
                address: caller,
                total_streams: 0,
                pending_rewards: 0,
                song_count: 0,
            };

            self.artists.write(new_id, artist);
            self.artist_by_address.write(caller, new_id);
            self.artist_count.write(new_id);

            self.emit(ArtistRegistered { artist_id: new_id, name, address: caller });

            new_id
        }

        fn claim_rewards(ref self: ComponentState<TContractState>, artist_id: felt252) {
            let caller = get_caller_address();
            let mut artist = self.artists.read(artist_id);

            assert(artist.address == caller, 'Not the artist');
            let amount = artist.pending_rewards;
            assert(amount > 0, 'No rewards to claim');

            artist.pending_rewards = 0;
            self.artists.write(artist_id, artist);

            self.emit(RewardsClaimed { artist_id, amount });
        }

        fn get_artist(self: @ComponentState<TContractState>, artist_id: felt252) -> Artist {
            self.artists.read(artist_id)
        }

        fn get_pending_rewards(self: @ComponentState<TContractState>, artist_id: felt252) -> u256 {
            self.artists.read(artist_id).pending_rewards
        }

        fn get_artist_by_address(
            self: @ComponentState<TContractState>, address: ContractAddress,
        ) -> Artist {
            let id = self.artist_by_address.read(address);
            self.artists.read(id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialise(ref self: ComponentState<TContractState>, guess_value: u64) {
            self.artist_count.write(0);
            self.incentive_guess_value.write(guess_value);
        }

        fn add_stream_reward(
            ref self: ComponentState<TContractState>, artist_id: felt252, stream_count: u64,
        ) {
            let mut artist = self.artists.read(artist_id);
            artist.total_streams += stream_count;

            let guess = self.incentive_guess_value.read();
            if guess > 0 {
                let reward: u256 = (stream_count / guess).into();
                artist.pending_rewards += reward;
            }

            self.artists.write(artist_id, artist);
        }

        fn increment_song_count(ref self: ComponentState<TContractState>, artist_id: felt252) {
            let mut artist = self.artists.read(artist_id);
            artist.song_count += 1;
            self.artists.write(artist_id, artist);
        }
    }
}
