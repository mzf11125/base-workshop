// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract RockPaperScissors is ERC721URIStorage {
    enum Move {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum GameStatus {
        Waiting,
        Ongoing,
        Finished
    }

    struct Game {
        address player1;
        address player2;
        Move move1;
        Move move2;
        GameStatus status;
        address winner;
    }

    address public owner;
    uint256 public gameCounter;
    mapping(uint256 => Game) public games;

    uint256 private _tokenIds; // 🔥 simple counter variable

    event GameCreated(uint256 indexed gameId, address indexed creator);
    event GameJoined(uint256 indexed gameId, address indexed joiner);
    event MoveSubmitted(uint256 indexed gameId, address indexed player);
    event GameFinished(uint256 indexed gameId, address winner);
    event NFTRedeemed(address indexed player, uint256 tokenId, uint256 gameId);
    event OwnershipTransferred(
        address indexed oldOwner,
        address indexed newOwner
    );

    error OnlyOwner();
    error InvalidGame(uint256 gameId);
    error InvalidMove();
    error NotYourTurn();
    error GameFull(uint256 gameId);
    error GameNotOngoing(uint256 gameId);
    error NotWinner(uint256 gameId);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor() ERC721("RPS Victory NFT", "RPSNFT") {
        owner = msg.sender;
    }

    function createGame() external returns (uint256) {
        gameCounter++;
        games[gameCounter] = Game({
            player1: msg.sender,
            player2: address(0),
            move1: Move.None,
            move2: Move.None,
            status: GameStatus.Waiting,
            winner: address(0)
        });
        emit GameCreated(gameCounter, msg.sender);
        return gameCounter;
    }

    function joinGame(uint256 gameId) external {
        Game storage g = games[gameId];
        if (g.player1 == address(0)) revert InvalidGame(gameId);
        if (g.player2 != address(0)) revert GameFull(gameId);

        g.player2 = msg.sender;
        g.status = GameStatus.Ongoing;
        emit GameJoined(gameId, msg.sender);
    }

    function submitMove(uint256 gameId, Move move) external {
        if (move == Move.None) revert InvalidMove();
        Game storage g = games[gameId];
        if (g.status != GameStatus.Ongoing) revert GameNotOngoing(gameId);

        if (msg.sender == g.player1) {
            require(g.move1 == Move.None, "Already played");
            g.move1 = move;
        } else if (msg.sender == g.player2) {
            require(g.move2 == Move.None, "Already played");
            g.move2 = move;
        } else {
            revert NotYourTurn();
        }

        emit MoveSubmitted(gameId, msg.sender);

        if (g.move1 != Move.None && g.move2 != Move.None) {
            _determineWinner(gameId);
        }
    }

    function _determineWinner(uint256 gameId) internal {
        Game storage g = games[gameId];

        if (g.move1 == g.move2) {
            g.winner = address(0); // Draw
        } else if (
            (g.move1 == Move.Rock && g.move2 == Move.Scissors) ||
            (g.move1 == Move.Paper && g.move2 == Move.Rock) ||
            (g.move1 == Move.Scissors && g.move2 == Move.Paper)
        ) {
            g.winner = g.player1;
        } else {
            g.winner = g.player2;
        }

        g.status = GameStatus.Finished;
        emit GameFinished(gameId, g.winner);
    }

    function redeemVictoryNFT(
        uint256 gameId,
        string memory tokenURI
    ) external returns (uint256) {
        Game memory g = games[gameId];
        if (g.status != GameStatus.Finished) revert GameNotOngoing(gameId);
        if (g.winner != msg.sender) revert NotWinner(gameId);

        _tokenIds++; // 🔥 just increment manually
        uint256 newItemId = _tokenIds;

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        emit NFTRedeemed(msg.sender, newItemId, gameId);
        return newItemId;
    }

    function getGame(uint256 gameId) external view returns (Game memory) {
        return games[gameId];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}