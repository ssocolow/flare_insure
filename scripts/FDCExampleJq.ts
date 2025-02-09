import { artifacts, ethers, run } from "hardhat";
import { CityRainfallListInstance } from "../typechain-types";

const CityRainfallList = artifacts.require("CityRainfallList");
const FDCHub = artifacts.require("@flarenetwork/flare-periphery-contracts/coston/IFdcHub.sol:IFdcHub");

// Simple hex encoding
function toHex(data: string) {
    var result = "";
    for (var i = 0; i < data.length; i++) {
        result += data.charCodeAt(i).toString(16);
    }
    return result.padEnd(64, "0");
}

const { JQ_VERIFIER_URL_TESTNET, JQ_API_KEY, VERIFIER_URL_TESTNET, VERIFIER_PUBLIC_API_KEY_TESTNET, DA_LAYER_URL_COSTON2 } = process.env;

const TX_ID =
    "0xae295f8075754f795142e3238afa132cd32930f871d21ccede22bbe80ae31f73";

// const STAR_WARS_LIST_ADDRESS = "0xE008098138A59C789bf0Ef525D639600116491D6"; // coston
const RAINFALL_LIST_ADDRESS = "0x335BCfba4aB4f3B9E052f13525D8017DB574b7C9"; // coston2

async function deployMainList() {
    const list: CityRainfallListInstance = await CityRainfallList.new();

    console.log("Rainfall list deployed at:", list.address);
    // verify 
    const result = await run("verify:verify", {
        address: list.address,
        constructorArguments: [],
    })
}

deployMainList().then((data) => {
    process.exit(0);
});


async function prepareRequest() {
    const attestationType = "0x" + toHex("IJsonApi");
    const sourceType = "0x" + toHex("WEB2");
    const requestData = {
        "attestationType": attestationType,
        "sourceId": sourceType,
        "requestBody": {
            "url": "https://ethoxford-vercel-api.vercel.app/api",
            "postprocessJq": `{
                nairobi: .Nairobi,
                accra: .Accra,
                lagos: .Lagos,
                lusaka: .Lusaka,
                addis_ababa: .Addis_Ababa
            }`,
            "abi_signature": `
            {\"components\": [
                {\"internalType\": \"uint16\",\"name\": \"nairobi\",\"type\": \"uint16\"},
                {\"internalType\": \"uint16\",\"name\": \"accra\",\"type\": \"uint16\"},
                {\"internalType\": \"uint16\",\"name\": \"lagos\",\"type\": \"uint16\"},
                {\"internalType\": \"uint16\",\"name\": \"lusaka\",\"type\": \"uint16\"},
                {\"internalType\": \"uint16\",\"name\": \"addis_ababa\",\"type\": \"uint16\"}
            ],
            \"name\": \"RainfallDTO\",\"type\": \"tuple\"}`
        }
    };
    // const requestData = {
    //     "attestationType": attestationType,
    //     "sourceId": sourceType,
    //     "requestBody": {
    //         "url": "https://swapi.dev/api/people/2/",
    //         "postprocessJq": `{
    //             name: .name,
    //             height: .height,
    //             mass: .mass,
    //             numberOfFilms: .films | length,
    //             uid: (.url | split("/") | .[-2] | tonumber)
    //         }`,
    //         "abi_signature": `
    //         {\"components\": [
    //             {\"internalType\": \"string\",\"name\": \"name\",\"type\": \"string\"},
    //             {\"internalType\": \"uint256\",\"name\": \"height\",\"type\": \"uint256\"},
    //             {\"internalType\": \"uint256\",\"name\": \"mass\",\"type\": \"uint256\"},
    //             {\"internalType\": \"uint256\",\"name\": \"numberOfFilms\",\"type\": \"uint256\"},
    //             {\"internalType\": \"uint256\",\"name\": \"uid\",\"type\": \"uint256\"}
    //         ],
    //         \"name\": \"task\",\"type\": \"tuple\"}`
    //     }
    // };

    const response = await fetch(
        `${JQ_VERIFIER_URL_TESTNET}JsonApi/prepareRequest`,
        {
            method: "POST",
            headers: {
                "X-API-KEY": JQ_API_KEY,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(requestData),
        },
    );
    const data = await response.json();
    console.log("Prepared request:", data);
    return data;
}


// prepareRequest().then((data) => {
//     console.log("Prepared request:", data);
//     process.exit(0);
// });

const firstVotingRoundStartTs = 1658430000;
const votingEpochDurationSeconds = 90;

async function submitRequest() {
    const requestData = await prepareRequest();

    const rainfallList: CityRainfallListInstance = await CityRainfallList.at(RAINFALL_LIST_ADDRESS);


    const fdcHUB = await FDCHub.at(await rainfallList.getFdcHub());

    // console.log(requestData);
    // Call to the FDC Hub protocol to provide attestation.
    const tx = await fdcHUB.requestAttestation(requestData.abiEncodedRequest, {
        value: ethers.parseEther("1").toString(),
    });
    console.log("Submitted request:", tx.tx);

    // Get block number of the block containing contract call
    const blockNumber = tx.blockNumber;
    const block = await ethers.provider.getBlock(blockNumber);

    // Calculate roundId
    const roundId = Math.floor(
        (block!.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds,
    );
    console.log(
        `Check round progress at: https://coston-systems-explorer.flare.rocks/voting-epoch/${roundId}?tab=fdc`,
    );
    return roundId;
}

// submitRequest().then((data) => {
//     console.log("Submitted request:", data);
//     process.exit(0);
// });





/*
Validation Work Below
*/


const TARGET_ROUND_ID = 895758; // 0

async function getProof(roundId: number) {
    const request = await prepareRequest();
    const proofAndData = await fetch(
        `${DA_LAYER_URL_COSTON2}fdc/get-proof-round-id-bytes`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                // "X-API-KEY": API_KEY,
            },
            body: JSON.stringify({
                votingRoundId: roundId,
                requestBytes: request.abiEncodedRequest,
            }),
        },
    );

    return await proofAndData.json();
}

// getProof(TARGET_ROUND_ID)
//     .then((data) => {
//         console.log("Proof and data:");
//         console.log(JSON.stringify(data, undefined, 2));
//     })
//     .catch((e) => {
//         console.error(e);
//     });


async function submitProof() {
    const dataAndProof = await getProof(TARGET_ROUND_ID);
    console.log(dataAndProof);
    const rainfallList = await CityRainfallList.at(RAINFALL_LIST_ADDRESS);

    const tx = await rainfallList.updateRainfall({
        merkleProof: dataAndProof.proof,
        data: dataAndProof.response,
    });
    console.log(tx.tx);
    console.log(await rainfallList.getAllCityData());
}


// submitProof()
//     .then((data) => {
//         console.log("Submitted proof");
//         process.exit(0);
//     })
//     .catch((e) => {
//         console.error(e);
//     });
