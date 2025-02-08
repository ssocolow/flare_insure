// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
struct CityData {
    string name;
    uint256 rainfall;
}

interface GreeterInterface {
    function getAllCityData() external view returns (CityData[] memory);
}

contract MyContract {
    address public constant OTHER_CONTRACT = 0xE008098138A59C789bf0Ef525D639600116491D6;
    GreeterInterface GreeterContract = GreeterInterface(OTHER_CONTRACT);

    function testCall() public view returns (CityData[] memory) {
        CityData[] memory cities = GreeterContract.getAllCityData();
        return cities;
    }
}