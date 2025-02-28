// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPSLS {
    uint8 public numPlayer = 0;
    uint public reward = 0;
    mapping(address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played; // not yet choose rock paper scissor
    mapping(address => bool) public player_not_revealed; // not yet choose rock paper scissor
    address[] public players;

    uint public numInput = 0;
    uint public numCommit = 0;
    uint public numReveal = 0;
    address public constant DEFAULT_ADDRESS =
        0x0000000000000000000000000000000000000000;
    mapping(address => bool) public is_allowed_player;

    TimeUnit public time_add_player = new TimeUnit();
    TimeUnit public time_input = new TimeUnit();
    TimeUnit public time_reveal = new TimeUnit();
    CommitReveal public commit_reveal = new CommitReveal();

    constructor() {
        is_allowed_player[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        is_allowed_player[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        is_allowed_player[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        is_allowed_player[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    event PlayerAdded(address player, uint8 playerNumber);
    event ChoiceCommitted(address player);
    event ChoiceRevealed(address player, uint choice);
    event GameReset();
    event GameWon(address winner, uint reward);
    event GameTied();

    function addPlayer() public payable {
        require(is_allowed_player[msg.sender]);
        require(numPlayer < 2); // only two player allowed
        if (numPlayer > 0) {
            // second player is being added
            require(msg.sender != players[0]); // second player can't be the same account as first player
        }
        require(msg.value == 1 ether); // player need to send 1 eth
        reward += msg.value;
        player_not_played[msg.sender] = true; // player not played
        player_not_revealed[msg.sender] = true; // player not revealed
        players.push(msg.sender); // add player
        numPlayer++;
        emit PlayerAdded(msg.sender, numPlayer - 1);
        if (numPlayer == 1) {
            time_add_player.setStartTime();
        }
    }

    function withdraw_no_player_2() public payable {
        require(numPlayer == 1); // only one player
        require(msg.sender == players[0]); // only player 1 can withdraw
        require(time_add_player.elapsedMinutes() > 1); // player 1 can withdraw after 1 minute
        address payable account0 = payable(players[0]);
        account0.transfer(reward); // send reward to player 1
        reward = 0;
        _resetGame();
    }

    function commit_choice(bytes32 choice_hash) public {
        require(numPlayer == 2); // need 2 player to play
        require(player_not_played[msg.sender]); // player not played only
        player_not_played[msg.sender] = false;
        numCommit++;

        commit_reveal.commit(choice_hash);

        emit ChoiceCommitted(msg.sender);
        if (numCommit == 1) {
            time_input.setStartTime();
        }
    }

    function withdraw_no_commit() public payable {
        require(numPlayer == 2); // need 2 player to play
        require(numCommit == 1); // only 1 player commit
        require(msg.sender == players[0] || msg.sender == players[1]); // only player 1 or 2 can withdraw
        require(time_input.elapsedMinutes() > 1); // player 1 or 2 can withdraw after 1 minute
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        account0.transfer(reward / 2); // send reward to player 1
        account1.transfer((reward + 1) / 2); // send reward to player 2
        reward = 0;
        _resetGame();
    }

    function reveal_choice(bytes32 choice_data) public {
        require(numPlayer == 2); // need 2 player to play
        require(numCommit == 2); // both player commit
        require(player_not_revealed[msg.sender]); // player not revealed only
        require(commit_reveal.reveal(choice_data)); // check if reveal is valid

        // choice is the last bytes of the choice_data
        player_choice[msg.sender] = uint8(choice_data[31]);

        if (player_choice[msg.sender] > 4) {
            player_choice[msg.sender] = 0;
        }

        player_not_revealed[msg.sender] = false;
        numInput++;

        emit ChoiceRevealed(msg.sender, player_choice[msg.sender]);
        if (numInput == 1) {
            time_reveal.setStartTime();
        }
        if (numInput == 2) {
            // after all player play , check winner
            _checkWinnerAndPay();
        }
    }

    function withdraw_no_reveal() public payable {
        require(numPlayer == 2); // need 2 player to play
        require(numInput == 1); // only 1 player reveal
        require(msg.sender == players[0] || msg.sender == players[1]); // only player 1 or 2 can withdraw
        require(time_reveal.elapsedMinutes() > 1); // player 1 or 2 can withdraw after 1 minute
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        account0.transfer(reward / 2); // send reward to player 1
        account1.transfer((reward + 1) / 2); // send reward to player 2
        reward = 0;
        _resetGame();
    }

    /* function input(uint choice) public  {
        require(numPlayer == 2); // need 2 player to play
        require(player_not_played[msg.sender]); // player not played only
        require(choice == 0 || choice == 1 || choice == 2 || choice == 3 || choice == 4); // limit choice
        player_choice[msg.sender] = choice; // add choice for player
        player_not_played[msg.sender] = false;
        numInput++;
        if (numInput == 2) { // after all player play , check winner
            _checkWinnerAndPay();
        }
    } */

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]); // make player able to be payed reward
        address payable account1 = payable(players[1]);

        if (p0Choice == p1Choice) {
            // It's a tie, split the reward
            account0.transfer(reward / 2);
            account1.transfer((reward + 1) / 2); // ensure all reward is sent
            reward = 0;
            emit GameTied();
        } else if (
            (p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) ||
            (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||
            (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||
            (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||
            (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))
        ) {
            // Player 0 wins
            account0.transfer(reward);
            emit GameWon(players[0], reward);
            reward = 0;
        } else {
            // Player 1 wins
            account1.transfer(reward);
            emit GameWon(players[1], reward);
            reward = 0;
        }

        _resetGame();
    }

    function _resetGame() private {
        // Reset player choices and played status
        player_choice[players[0]] = 0;
        player_choice[players[1]] = 0;
        player_not_played[players[0]] = true;
        player_not_played[players[1]] = true;

        // Reset players array and number of players
        delete players; // This will remove all elements from the array
        numPlayer = 0;
        numInput = 0;
        numCommit = 0;
        numReveal = 0;
        reward = 0; // Reset the reward
        commit_reveal.reset();
    }
}
