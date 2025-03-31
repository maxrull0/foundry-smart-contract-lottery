// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {RevertReceiver} from "test/mocks/RevertReceiver.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig.NetworkConfig public networkConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    uint256 public constant STARTING_BALANCE_PLAYER = 10 ether;

    function setUp() public {
        // set block.number to 1 to prevent underflow with VRFCoordinatorV2_5Mock.createSubscription()
        vm.roll(1);
        // set block.timestamp to 1
        vm.warp(1);
        DeployRaffle deployer = new DeployRaffle();
        (raffle, networkConfig) = deployer.deployContract();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        callbackGasLimit = networkConfig.callbackGasLimit;
        subscriptionId = networkConfig.subscriptionId;

        vm.deal(PLAYER, STARTING_BALANCE_PLAYER);
        vm.deal(PLAYER2, STARTING_BALANCE_PLAYER);

        // set labels for entities
        vm.label(PLAYER, "player");
        vm.label(address(this), "RaffleTest");
        vm.label(address(raffle), "raffle");
        vm.label(address(vrfCoordinator), "vrfCoordinator");
        vm.label(address(deployer), "deployer");
    }

    /////////////////////////////
    //        Modifiers        // 
    /////////////////////////////

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval); // interval passed, will make checkUpkeep return true
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }


    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////////////
    //        Enter Raffle         //
    /////////////////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // prank as player, call enterRaffle on the raffle with not enough ether, expect revert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // prank as player, call enterRaffle on the raffle with enough ether
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // check that the player is in the list of players
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testRaffleEmitsEventWhenPlayerEnters() public {
        // prank as player, call enterRaffle on the raffle with enough ether
        vm.prank(PLAYER);
        // check that the event was emitted
        /*
        /// Prepare an expected log with (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData.).
        /// Call this function, then emit an event, then call a function. Internally after the call, we check if
        /// logs were emitted in the expected order with the expected topics and data (as specified by the booleans).
        function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;

        /// Same as the previous method, but also checks supplied address against emitting contract.
        function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter) external;
        */
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEntered {
        // prank as player, call enterRaffle on the raffle with enough ether
        // raffle Entered

        // call performUpkeep on the raffle to force calculating state
        raffle.performUpkeep("");

        // try to enter raffle which should revert as raffle is calculating
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////////////////////////////////////////
    //        Check Upkeep         //
    /////////////////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
        // Arrange: make a calculating raffle
        // raffleEntered
        raffle.performUpkeep(""); // call performUpkeep to make the raffle calculating

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assertFalse(upkeepNeeded);
    }

    
    //////////////////////////////////////////
    //              performUpkeep           //
    //////////////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange: make a calculating raffle

        // Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange: make a calculating raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1); // interval did not pass, will make checkUpkeep return false
        vm.roll(block.number + 1);

        uint256 raffleBalance = entranceFee;
        uint256 playersLength = 1;
        uint256 raffleState = uint256(Raffle.RaffleState.OPEN);

        // Act/Assert
        // expect revert:
        // Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState))
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                raffleBalance,
                playersLength,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesStateAndEmitsRequestId() public raffleEntered {
        // Arrange: make a calculating raffle
        // raffleEntered

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == uint256(Raffle.RaffleState.CALCULATING));
    }

    //////////////////////////////////////////
    //              fulfillRandomWords      //
    //////////////////////////////////////////


    // my tests

    function testFulfillRandomWordsCalculatesWinnerCorrectly() public raffleEntered {
        // Arrange: make a calculating raffle
        // raffleEntered
        raffle.performUpkeep(""); // call performUpkeep to make the raffle calculating

        // Act: call fulfillRandomWords with a random number
        uint256 randomWord = 0;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.WinnerPicked(PLAYER);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(0, randomWords);

        // Assert: check that the winner is the player
        assertEq(raffle.getRecentWinner(), PLAYER);
    }

    function testFulfillRandomWordsResetsRaffleStateAfterCalculation() public {

        // Arrange: make a calculating raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entranceFee}();

        // make time passed by setting blocktime + interval
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // call performUpkeep to make the raffle calculating

        // Act: call fulfillRandomWords with a random number
        uint256 randomWord = 13371337;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        uint winnerIndex = randomWords[0] % raffle.getPlayersLength();
        address winner = raffle.getPlayer(winnerIndex);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(0, randomWords);

        // Assert: check that the raffle state is open, no players and last timestamp is updated
        assertEq(raffle.getRecentWinner(), winner);
        assertEq(raffle.getPlayersLength(), 0);
        assertEq(raffle.getLastTimeStamp(), block.timestamp);
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    function testFulfillRandomWordsWinnerReceivesFullFundsOfRaffleContract() public {

        // Arrange: make a calculating raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // call performUpkeep to make the raffle calculating
        uint256 raffleWinningPotBalance = address(raffle).balance;

        // Act: call fulfillRandomWords with a random number
        uint256 randomWord = 0;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(0, randomWords);

        // Assert: check that the winner receives the full balance of the contract
        assertEq(raffle.getRecentWinner().balance, STARTING_BALANCE_PLAYER - entranceFee + raffleWinningPotBalance);
        assertEq(address(raffle).balance, 0);
    }

    // course tests

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        skipFork
        raffleEntered
    {

        // test that there is no valid response without a request 

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

        // fuzzing that for all requestId's the fulfillRandomWords function (respond with randomness to the raffle contract) cannot execute as no requestId has been created yet using performUpkeep (request randonmess function)

    }

    function testFulfillRandomWordsPicksAWinnerResetsArrayAndSendsMoney() public skipFork raffleEntered {
        ////// Arrange //////
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1); // precalculated

        // add 3 more players to the raffle
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_BALANCE_PLAYER);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        ////// Act //////
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Make sure that the subscription is sufficiently funded for the randomWords fulfillment
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        ////// Assert //////

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        // picks a winner
        assert(recentWinner == expectedWinner);

        // resets the state
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(endingTimeStamp > startingTimeStamp);

        // sends the money to the winner
        assert(winnerBalance == winnerStartingBalance + prize);
    }

    function testFulfillRandomWordsRevertsIfWinnerCannotReceivePrize() public {

        // Arrange
        RevertReceiver revertReceiver = new RevertReceiver();
        hoax(address(revertReceiver), STARTING_BALANCE_PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        uint256 randomWord = 0;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;


        // Act & Assert
        raffle.performUpkeep("");

        // expect revert on transfer to winner after fulfillRandomWords callback of the performUpkeep
        vm.expectRevert(Raffle.Raffle__TransferFailed.selector);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(0, randomWords);
    }

}

