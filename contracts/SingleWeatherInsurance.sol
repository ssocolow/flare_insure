// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


/* Notes:
No returns, right now just emits (can change if easier on frontend)
Make sure this is currency agnostic?
Don't actually need ID of transaction (would require a third level contract) technically, you can just check the location.
*/



/*
Notes/edge cases about this (doesn't enough to implement, just be preparted to explain if asked)
- technically suboptimal to have the insurer lock up funds (sale of contract has not occured yet, limits how many floating contracts)
    - Make sure that exists a way to cancel the contract if we are locking up funds at initialization, otherwise fudns stuck ehre.
- Security vulnerabilit: order of operations of confirming payment (should confirm before senidng payent ot avoid atacks)

*/


// Interface for the GetWeatherData Contract
// interface IWeatherOracle {
//     function getRainfall(string memory location) external view returns (uint256);
// }



contract SingleWeatherInsurance {
    // A struct that contains all the state for the insurance policy.
    struct Policy {
        address insurer;
        address policyholder;
        uint256 maturitySecond;    // The timestamp at which the policy matures.
        uint256 purchaseDeadline;  // The deadline by which the policy must be purchased.
        bool isFinalized;          // Set to true once the policyholder has purchased the policy.
        bool isPaidOut;            // Set to true after a payout is made.
        uint256 coverage;          // The amount that will be paid out if the weather condition is met.
        uint256 premium;           // The premium the policyholder must pay to buy the insurance.
        string location;          // Encoded location identifier for the weather data.
        uint256 threshold;         // Weather threshold for payout (e.g., rainfall limit).
    }

    // For when the GetWeatherData contract is up on chain
    //IWeatherOracle public constant WEATHER_ORACLE = IWeatherOracle(0x123...);

    Policy public policy;

    // A constant settlement window
    uint256 public constant SETTLEMENT_WINDOW = 7 days;

    // Events for logging contract activity.
    event ContractCreated(address insurer, uint256 coverage, uint256 premium);
    event InsurancePurchased(address policyholder);
    event ContractSettled(address recipient, uint256 amount);
    event ContractCancelled();

    /**
     * @notice Constructor for creating a new weather insurance policy.
     * @param _maturitySecond The duration (in seconds) until the policy matures.
     * @param _coverage The amount to be covered by the policy.
     * @param _premium The premium the policyholder must pay.
     * @param _location The weather location to monitor.
     * @param _threshold The weather threshold for triggering a payout.
     */
    constructor(
        uint256 _maturitySecond,
        uint256 _coverage,
        uint256 _premium,
        string memory _location,
        uint256 _threshold
    ) payable {
        // The insurer must deposit the full coverage amount upon contract creation.
        require(msg.value >= _coverage, "Must deposit full coverage");

        policy.insurer = msg.sender;
        // Set the maturity time based on the current timestamp plus the provided duration.
        policy.maturitySecond = block.timestamp + _maturitySecond; // Literally 1 second before is fine
        policy.purchaseDeadline = policy.maturitySecond - 1 seconds;
        policy.coverage = _coverage;
        policy.premium = _premium;
        policy.location = _location;
        policy.threshold = _threshold;

        emit ContractCreated(msg.sender, _coverage, _premium);
    }

    // Allows a policyholder to purchase the insurance by paying the premium.

    function purchase() public payable {
        require(!policy.isFinalized, "Already finalized");
        require(policy.policyholder == address(0), "Policy already purchased"); // Basically policyholder is initialized to 0, means not set yet.
        require(msg.value == policy.premium, "Must pay exact premium");
        require(block.timestamp < policy.purchaseDeadline, "Contract has expired");

        policy.policyholder = msg.sender;

        // Transfer the premium to the insurer up front
        (bool sent, ) = payable(policy.insurer).call{value: policy.premium}("");
        require(sent, "Failed to send premium to insurer");

        policy.isFinalized = true;
        emit InsurancePurchased(msg.sender);
    }

    /**
     * @notice Dummy settlement function. (COMMENT OUT IN PROD)
     * @dev In this simplified version, the caller provides the weather condition outcome.
     * If `weatherConditionMet` is true, the policyholder receives the coverage amount.
     * Otherwise, the insurer gets their deposit back.
     * @param weatherConditionMet Indicates if the weather condition triggering a payout was met.
     */
    function autoSettle(bool weatherConditionMet) public {
        require(block.timestamp >= policy.maturitySecond, "Not mature yet");
        require(!policy.isPaidOut, "Already paid out");
        require(policy.isFinalized, "Contract not finalized");

        // Decide who should receive the payout.
        address payable recipient;
        if (weatherConditionMet) {
            recipient = payable(policy.policyholder);
        } else {
            recipient = payable(policy.insurer);
        }


        uint256 amount = policy.coverage;
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send payment");

        policy.isPaidOut = true;
        emit ContractSettled(recipient, amount);
    }



    // Called at maturity to settle the contract. Uncomment when GetWeatherData is up (relies on that connection via address)
    // function settle() public {
    //     require(block.timestamp >= maturitySecond, "Not mature yet");
    //     require(!isPaidOut, "Already paid out");
    //     require(isFinalized, "Contract not finalized");


    //     // First set our state before making external calls
    //     isPaidOut = true;

    //     // 1. First check if we are past settlement window
    //     // funds automatically return to insurer
    //     if (block.timestamp > maturitySecond + SETTLEMENT_WINDOW) {
    //         // Past settlement window, return funds to insurer
    //         (bool sent, ) = payable(insurer).call{value: coverage}("");
    //         if (!sent) {
    //             isPaidOut = false;
    //             revert("Failed to send payment");
    //         }
    //         emit ContractSettled(insurer, coverage);
    //         return;  // Exit the function here
    //     }

    //     // 2. If not, we can proceed with processing the settlement to policyholder
    //     // Get rainfall data from oracle
    //     uint256 rainfall = WEATHER_ORACLE.getRainfall(location);
        
    //     // Determine recipient based on rainfall
    //     address payable recipient;
    //     if (rainfall < threshold) {
    //         // If rainfall is below threshold, policyholder gets paid
    //         recipient = payable(policyholder);
    //     } else {
    //         // If rainfall is above threshold, insurer gets their deposit back
    //         recipient = payable(insurer);
    //     }
        
    //     // Send payment
    //     uint256 amount = coverage;
    //     (bool sent, ) = recipient.call{value: amount}("");
    //     if (!sent) {
    //         isPaidOut = false;  // Reset state if payment fails
    //         revert("Failed to send payment");
    //     }
        
    //     emit ContractSettled(recipient, amount);
    // }

    // Allows the insurer to cancel the policy before it is purchased.
    function cancel() public {
        require(msg.sender == policy.insurer, "Only insurer can cancel");
        require(!policy.isFinalized, "Policy already purchased");

        // Return the full coverage deposit back to the insurer.
        (bool sent, ) = policy.insurer.call{value: policy.coverage}("");
        require(sent, "Failed to return deposit");

        emit ContractCancelled();
    }

    function getContractStatus() public view returns (
        address _insurer,
        address _policyholder,
        bool _isFinalized,
        bool _isPaidOut,
        uint256 _coverage,
        uint256 _premium,
        uint256 _maturitySecond,
        uint256 _purchaseDeadline
    ) {
        return (
            policy.insurer,
            policy.policyholder,
            policy.isFinalized,
            policy.isPaidOut,
            policy.coverage,
            policy.premium,
            policy.maturitySecond,
            policy.purchaseDeadline
        );
    }
}




  

  