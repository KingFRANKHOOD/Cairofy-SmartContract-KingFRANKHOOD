use starknet::ContractAddress;

/// Represents an artist registered on the Cairofy platform.
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Artist {
    pub id: felt252,
    pub name: felt252,
    pub owner: ContractAddress,
    pub total_streams: u64,
    pub pending_rewards: u256,
    pub song_count: u64,
    pub exists: bool,
}

/// Interface for the Cairofy Artist component.
///
/// Handles artist registration, profile management and the reward system
/// described in the project README: `Incentive Reward = Count / Guess Value`.
#[starknet::interface]
pub trait IArtist<TContractState> {
    /// Registers the caller as a new artist with the given display name.
    /// Returns the newly assigned artist id.
    fn register_artist(ref self: TContractState, name: felt252) -> felt252;

    /// Updates the display name of an existing artist profile.
    /// Only the artist's owner may update their own profile.
    fn update_artist_profile(ref self: TContractState, artist_id: felt252, name: felt252);

    /// Records new streams for an artist and accrues pending rewards using
    /// the platform's incentive formula (stream_count / incentive_guess_value).
    fn record_streams(ref self: TContractState, artist_id: felt252, stream_count: u64);

    /// Claims all pending rewards owed to an artist, resetting the balance to
    /// zero and returning the claimed amount. Only the artist's owner may claim.
    fn claim_rewards(ref self: TContractState, artist_id: felt252) -> u256;

    /// Increments the number of songs owned by an artist. Intended to be
    /// called by the song/marketplace components when a new song is registered.
    fn increment_song_count(ref self: TContractState, artist_id: felt252);

    /// Returns the full artist record.
    fn get_artist(self: @TContractState, artist_id: felt252) -> Artist;

    /// Returns the amount of unclaimed rewards currently owed to an artist.
    fn get_pending_rewards(self: @TContractState, artist_id: felt252) -> u256;

    /// Returns the artist id registered to a given address, or 0 if none.
    fn get_artist_id_by_owner(self: @TContractState, owner: ContractAddress) -> felt252;

    /// Returns whether the given artist id corresponds to a registered artist.
    fn is_registered(self: @TContractState, artist_id: felt252) -> bool;
}
