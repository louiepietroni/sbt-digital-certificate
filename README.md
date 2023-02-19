# sbt-digital-certificate

## About and Motivation

This is a project designed to allow certificates and qualifications to be stored as soul bound tokens. A soul bound token is similar to an NFT, with the difference being that the token cannot be traded. This means it does not have a monetary value, but can be used to prove ownership or completion of something.

The idea is that a company/university/course provider will issue a certifcate to a user. The recipient will be able to view their pending offers, which can then be accepted. At this point, a soul bound token is minted to their address containing the information of the certificate. The information of the SBTs can be viewed normally with an NFT, however the issuing address and the burn auth of the token are extra pieces of information which are also stored.

## Deployment

To run this code, it will need to be deployed onto the blockchain. This can be done for free at https://remix.ethereum.org
Once deployed, the contract can be interacted with using the external functions.

## Usage

First, the data of a certificate needs to be uploaded to IPFS. Then this URI, along with the burn auth of the token and the recipients address are passed to the smart contract.

The recipient will then be able to view their pending offers using `getNumberOfOffers` and `getOfferByIndex`. Then, having viewed their offers, the user can reject the offer, meaning it'll be deleted, or accept it at which point it'll be minted as a Soul Bound Token. The reason for requiring the recipient to approve an offer is for the burn auth. This determines who has the right to burn the token and is immutable. By ensuring the offer is accepted by the user, malicious actors can't force users to accept soul bound tokens they would be stuck with.

The tokens are enumerable, making it easy to find the tokens belonging to an address. The smart contract also stores a mapping of tokenID to burn auth and issuer, so both of these pieces of information are available for each token.

*Burn auth is an enum of Issuer only, Owner only, Both, Neither. It determines who has the right to burn the token and is immutable.
