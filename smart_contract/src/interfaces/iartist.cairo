
use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Artist {
    pub id: felt252,
    pub name: felt252,
    pub address: ContractAddress,
    pub total_streams: u64,
    pub pending_rewards: u256,
    pub song_count: u64,
}

#[starknet::interface]
pub trait IArtist<TContractState> {
    fn register_artist(ref self: TContractState, name: felt252) -> felt252;
    fn claim_rewards(ref self: TContractState, artist_id: felt252);
    fn get_artist(self: @TContractState, artist_id: felt252) -> Artist;
    fn get_pending_rewards(self: @TContractState, artist_id: felt252) -> u256;
    fn get_artist_by_address(self: @TContractState, address: ContractAddress) -> Artist;
}
