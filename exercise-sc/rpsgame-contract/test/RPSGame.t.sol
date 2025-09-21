// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/RPSGame.sol";

contract RockPaperScissorsTest is Test {
    RockPaperScissors rps;
    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    function setUp() public {
        rps = new RockPaperScissors();
    }

    function testCreateGame() public {
        vm.prank(alice);
        uint256 gameId = rps.createGame();
        RockPaperScissors.Game memory g = rps.getGame(gameId);
        assertEq(g.player1, alice);
        assertEq(uint(g.status), uint(RockPaperScissors.GameStatus.Waiting));
    }

    function testJoinGame() public {
        vm.startPrank(alice);
        uint256 gameId = rps.createGame();
        vm.stopPrank();

        vm.prank(bob);
        rps.joinGame(gameId);

        RockPaperScissors.Game memory g = rps.getGame(gameId);
        assertEq(g.player2, bob);
        assertEq(uint(g.status), uint(RockPaperScissors.GameStatus.Ongoing));
    }

    function testSubmitMovesAndDetermineWinner() public {
        vm.startPrank(alice);
        uint256 gameId = rps.createGame();
        vm.stopPrank();

        vm.prank(bob);
        rps.joinGame(gameId);

        vm.prank(alice);
        rps.submitMove(gameId, RockPaperScissors.Move.Rock);

        vm.prank(bob);
        rps.submitMove(gameId, RockPaperScissors.Move.Scissors);

        RockPaperScissors.Game memory g = rps.getGame(gameId);
        assertEq(g.winner, alice);
        assertEq(uint(g.status), uint(RockPaperScissors.GameStatus.Finished));
    }

    function testDrawGame() public {
        vm.startPrank(alice);
        uint256 gameId = rps.createGame();
        vm.stopPrank();

        vm.prank(bob);
        rps.joinGame(gameId);

        vm.prank(alice);
        rps.submitMove(gameId, RockPaperScissors.Move.Rock);
    }

    function testRedeemVictoryNFT_WinnerMintsAndUriSet() public {
        // Alice creates, Bob joins; Alice(Paper) beats Bob(Rock)
        vm.prank(alice);
        uint256 gameId = rps.createGame();

        vm.prank(bob);
        rps.joinGame(gameId);

        vm.prank(alice);
        rps.submitMove(gameId, RockPaperScissors.Move.Paper);

        vm.prank(bob);
        rps.submitMove(gameId, RockPaperScissors.Move.Rock);

        string memory uri = "ipfs://victory1";
        vm.prank(alice);
        uint256 tokenId = rps.redeemVictoryNFT(gameId, uri);

        assertEq(rps.ownerOf(tokenId), alice);
        assertEq(rps.tokenURI(tokenId), uri);
    }

    function testRedeemVictoryNFT_RevertIfNotWinner() public {
        // Bob wins: Bob(Paper) beats Alice(Rock); Alice tries to redeem
        vm.prank(alice);
        uint256 gameId = rps.createGame();

        vm.prank(bob);
        rps.joinGame(gameId);

        vm.prank(alice);
        rps.submitMove(gameId, RockPaperScissors.Move.Rock);

        vm.prank(bob);
        rps.submitMove(gameId, RockPaperScissors.Move.Paper);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(RockPaperScissors.NotWinner.selector, gameId)
        );
        rps.redeemVictoryNFT(gameId, "ipfs://should-revert");
    }

    function testRedeemVictoryNFT_RevertIfGameNotFinished() public {
        // Only Alice has submitted a move; game is Ongoing
        vm.prank(alice);
        uint256 gameId = rps.createGame();

        vm.prank(bob);
        rps.joinGame(gameId);

        vm.prank(alice);
        rps.submitMove(gameId, RockPaperScissors.Move.Rock);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                RockPaperScissors.GameNotOngoing.selector,
                gameId
            )
        );
        rps.redeemVictoryNFT(gameId, "ipfs://should-revert");
    }
}