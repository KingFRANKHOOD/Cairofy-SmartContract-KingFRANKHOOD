/// Artist component: registration, profile management, and the streaming
/// reward system described in `Readme.md` (`Incentive Reward = Count / Guess Value`).
#[starknet::contract]
pub mod ArtistComponent {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::interfaces::iartist::{Artist, IArtist};

    /// Divisor used to convert raw stream counts into reward tokens, as
    /// defined by the platform's incentive formula.
    const INCENTIVE_GUESS_VALUE: u64 = 100;

    #[storage]
    struct Storage {
        artists: Map<felt252, Artist>,
        artist_count: felt252,
        owner_to_artist_id: Map<ContractAddress, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ArtistRegistered: ArtistRegistered,
        ArtistProfileUpdated: ArtistProfileUpdated,
        StreamsRecorded: StreamsRecorded,
        RewardsClaimed: RewardsClaimed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtistRegistered {
        pub artist_id: felt252,
        pub owner: ContractAddress,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArtistProfileUpdated {
        pub artist_id: felt252,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamsRecorded {
        pub artist_id: felt252,
        pub stream_count: u64,
        pub reward_accrued: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsClaimed {
        pub artist_id: felt252,
        pub amount: u256,
    }

    #[abi(embed_v0)]
    impl ArtistImpl of IArtist<ContractState> {
        fn register_artist(ref self: ContractState, name: felt252) -> felt252 {
            let caller = get_caller_address();
            let existing_id = self.owner_to_artist_id.entry(caller).read();
            assert(existing_id == 0, 'Artist already registered');

            let new_id = self.artist_count.read() + 1;
            self.artist_count.write(new_id);

            let artist = Artist {
                id: new_id,
                name,
                owner: caller,
                total_streams: 0,
                pending_rewards: 0,
                song_count: 0,
                exists: true,
            };
            self.artists.entry(new_id).write(artist);
            self.owner_to_artist_id.entry(caller).write(new_id);

            self.emit(ArtistRegistered { artist_id: new_id, owner: caller, name });

            new_id
        }

        fn update_artist_profile(ref self: ContractState, artist_id: felt252, name: felt252) {
            let mut artist = self.artists.entry(artist_id).read();
            assert(artist.exists, 'Artist does not exist');
            assert(artist.owner == get_caller_address(), 'Caller is not the owner');

            artist.name = name;
            self.artists.entry(artist_id).write(artist);

            self.emit(ArtistProfileUpdated { artist_id, name });
        }

        fn record_streams(ref self: ContractState, artist_id: felt252, stream_count: u64) {
            let mut artist = self.artists.entry(artist_id).read();
            assert(artist.exists, 'Artist does not exist');

            let reward_accrued: u256 = (stream_count / INCENTIVE_GUESS_VALUE).into();

            artist.total_streams = artist.total_streams + stream_count;
            artist.pending_rewards = artist.pending_rewards + reward_accrued;
            self.artists.entry(artist_id).write(artist);

            self.emit(StreamsRecorded { artist_id, stream_count, reward_accrued });
        }

        fn claim_rewards(ref self: ContractState, artist_id: felt252) -> u256 {
            let mut artist = self.artists.entry(artist_id).read();
            assert(artist.exists, 'Artist does not exist');
            assert(artist.owner == get_caller_address(), 'Caller is not the owner');

            let amount = artist.pending_rewards;
            assert(amount > 0, 'No rewards to claim');

            artist.pending_rewards = 0;
            self.artists.entry(artist_id).write(artist);

            self.emit(RewardsClaimed { artist_id, amount });

            amount
        }

        fn increment_song_count(ref self: ContractState, artist_id: felt252) {
            let mut artist = self.artists.entry(artist_id).read();
            assert(artist.exists, 'Artist does not exist');

            artist.song_count = artist.song_count + 1;
            self.artists.entry(artist_id).write(artist);
        }

        fn get_artist(self: @ContractState, artist_id: felt252) -> Artist {
            self.artists.entry(artist_id).read()
        }

        fn get_pending_rewards(self: @ContractState, artist_id: felt252) -> u256 {
            self.artists.entry(artist_id).read().pending_rewards
        }

        fn get_artist_id_by_owner(self: @ContractState, owner: ContractAddress) -> felt252 {
            self.owner_to_artist_id.entry(owner).read()
        }

        fn is_registered(self: @ContractState, artist_id: felt252) -> bool {
            self.artists.entry(artist_id).read().exists
        }
    }
}
