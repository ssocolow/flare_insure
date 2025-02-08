// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";

// Dummy import to get artifacts for IFDCHub
import {IFdcHub} from "@flarenetwork/flare-periphery-contracts/coston2/IFdcHub.sol";
import {IFdcRequestFeeConfigurations} from "@flarenetwork/flare-periphery-contracts/coston2/IFdcRequestFeeConfigurations.sol";

import {IJsonApiVerification} from "@flarenetwork/flare-periphery-contracts/coston2/IJsonApiVerification.sol";
import {IJsonApi} from "@flarenetwork/flare-periphery-contracts/coston2/IJsonApi.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

enum CityIndex {
    NAIROBI,
    ACCRA,
    LAGOS,
    ADDIS_ABABA,
    LUSAKA
}

struct CityData {
    string name;
    uint256 rainfall;
}

struct RainfallDTO {
    uint256 nairobi;
    uint256 accra;
    uint256 lagos;
    uint256 addis_ababa;
    uint256 lusaka;
}

// struct city {
//     uint256 rainfall;
// }


// edge cases don't matter rn - this is a hackathon

// contract StarWarsCharacterList {
contract CityRainfallList {
    // want to make a mapping between ids of places and their rainfall
    // but for now will do with just the five places
    // mapping(uint256 => StarWarsCharacter) public characters;
    // uint256[] public characterIds;

    // Fixed array since we know we have exactly 5 cities
    CityData[5] public cities;
    
    constructor() {
        // Initialize city names
        cities[uint(CityIndex.NAIROBI)] = CityData("Nairobi", 0);
        cities[uint(CityIndex.ACCRA)] = CityData("Accra", 0);
        cities[uint(CityIndex.LAGOS)] = CityData("Lagos", 0);
        cities[uint(CityIndex.ADDIS_ABABA)] = CityData("Addis Ababa", 0);
        cities[uint(CityIndex.LUSAKA)] = CityData("Lusaka", 0);
    }

    function isJsonApiProofValid(
        IJsonApi.Proof calldata _proof
    ) public view returns (bool) {
        // Inline the check for now until we have an official contract deployed
        return
            ContractRegistry.auxiliaryGetIJsonApiVerification().verifyJsonApi(
                _proof
            );
    }

    function updateRainfall(IJsonApi.Proof calldata data) public {
        require(isJsonApiProofValid(data), "Invalid proof");

        RainfallDTO memory dto = abi.decode(
            data.data.responseBody.abi_encoded_data,
            (RainfallDTO)
        );

        // Update all cities at once from the API response
        cities[uint(CityIndex.NAIROBI)].rainfall = dto.nairobi;
        cities[uint(CityIndex.ACCRA)].rainfall = dto.accra;
        cities[uint(CityIndex.LAGOS)].rainfall = dto.lagos;
        cities[uint(CityIndex.ADDIS_ABABA)].rainfall = dto.addis_ababa;
        cities[uint(CityIndex.LUSAKA)].rainfall = dto.lusaka;
    }

    function getAllCityData() public view returns (CityData[] memory) {
        CityData[] memory allCities = new CityData[](5);
        for (uint i = 0; i < 5; i++) {
            allCities[i] = cities[i];
        }
        return allCities;
    }

    // function addCharacter(IJsonApi.Proof calldata data) public {
    //     require(isJsonApiProofValid(data), "Invalid proof");

    //     DataTransportObject memory dto = abi.decode(
    //         data.data.responseBody.abi_encoded_data,
    //         (DataTransportObject)
    //     );

    //     require(characters[dto.apiUid].apiUid == 0, "Character already exists");

    //     StarWarsCharacter memory character = StarWarsCharacter({
    //         name: dto.name,
    //         numberOfMovies: dto.numberOfMovies,
    //         apiUid: dto.apiUid,
    //         bmi: (dto.mass * 100 * 100) / (dto.height * dto.height)
    //     });

    //     characters[dto.apiUid] = character;
    //     characterIds.push(dto.apiUid);
    // }

    function getFdcHub() external view returns (IFdcHub) {
        return ContractRegistry.getFdcHub();
    }

    function getFdcRequestFeeConfigurations()
        external
        view
        returns (IFdcRequestFeeConfigurations)
    {
        return ContractRegistry.getFdcRequestFeeConfigurations();
    }
}
