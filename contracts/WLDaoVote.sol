// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum Option {
    A,
    B
}

struct Proposal {
    string title;
    string description;
    address voteToken;
    uint256 voteBlock;
    uint256 proposalDeadline;
    uint256 votesForOptionA;
    uint256 votesForOptionB;
    uint256 minimumVotes;
    uint256 voterCount;
    uint256 votingPowerSum;
    uint128 successOverRate;
    string nameForOptionA;
    string nameForOptionB;
    string ipfsHash;
    string ipfsFileName;
    bool aborted;
    bool executed;
    bool isSuccess;
}

struct VPower {
    uint256 proposalId;
    uint256 index;
    bool isSet;
    uint256 value;
    uint256 power;
}

struct Winner {
    uint256 proposalId;
    string title;
    string nameForOption;
}

contract WLDaoVote is Ownable {
    // Checkpoint 3: In ProposalCreated, include minimumVotes as a parameter of the same type as in the Proposal struct
    // Checkpoint 4: In ProposalCreated, include newly added Proposal struct values
    event ProposalCreated(
        uint256 proposalId,
        string title,
        address voteToken,
        uint256 voteBlock,
        uint256 proposalDeadline,
        uint256 minimumVotes,
        uint128 successOverRate,
        string nameForOptionA,
        string nameForOptionB
    );

    event VoteCasted(uint256 proposalId, address voter, Option selectedOption);

    event VotePower(uint256 proposalId, address voter, uint256 power);

    event VotePowerBatch(uint256 proposalId, uint256 setCount);

    mapping(uint256 => Proposal) private proposals;
    // Checkpoint 5: Create a mapping from uint256 (proposal id) to Winner struct
    mapping(uint256 => Winner) private winners;
    mapping(uint256 => mapping(address => bool)) private hasVoted;
    mapping(uint256 => mapping(uint256 => address)) private voterIndex;
    mapping(uint256 => mapping(address => VPower)) private votingPower;
    //mapping(address => mapping(uint256 => Option)) private voterOption;

    uint256 private proposalCounter;

    function createProposal(
        // string memory _title,
        // string memory _description,
        // address _voteToken,
        // uint256 _voteBlock,
        // uint256 _proposalDurationInMinutes,
        // uint256 _minimumVotes,
        // uint128 _successOverRate,
        // string memory _nameForOptionA,
        // string memory _nameForOptionB,
        // string memory _ipfsHash,
        // string memory _ipfsFileName
        Proposal memory newProposal,
        uint256 proposalDurationInMinutes
    ) public virtual onlyOwner {
        require(
            proposalDurationInMinutes > 0,
            "Proposal duration must be greater than zero"
        );
        require(
            newProposal.minimumVotes > 0,
            "Minimum votes must be greater than zero"
        );
        //require(_voteToken > 0, "Minimum votes must be greater than zero");
        require(
            newProposal.successOverRate >= 0,
            "Success Over Rate must be greater than or equal zero"
        );

        // Proposal memory newProposal;
        // newProposal.title = newProposal.title;
        // newProposal.description = newProposal.description;
        // newProposal.voteToken = newProposal.voteToken;
        // newProposal.voteBlock = newProposal.voteBlock;
        // newProposal.proposalDeadline =
        //     block.timestamp +
        //     (proposalDurationInMinutes * 1 minutes);
        // newProposal.minimumVotes = newProposal.minimumVotes;
        // newProposal.voterCount = 0;
        // newProposal.votingPowerSum = 0;
        // newProposal.successOverRate = newProposal.successOverRate;
        // newProposal.nameForOptionA = newProposal.nameForOptionA;
        // newProposal.nameForOptionB = newProposal.nameForOptionB;
        // newProposal.ipfsHash = newProposal.ipfsHash;
        // newProposal.ipfsFileName = newProposal.ipfsFileName;

        newProposal.proposalDeadline =
            block.timestamp +
            (proposalDurationInMinutes * 1 minutes);
        newProposal.voterCount = 0;
        newProposal.votingPowerSum = 0;
        uint256 proposalId = proposalCounter;
        proposals[proposalCounter] = newProposal;
        proposalCounter++;

        emit ProposalCreated(
            proposalId,
            newProposal.title,
            // newProposal.voteToken,
            // newProposal.voteBlock,
            // newProposal.proposalDeadline,
            // newProposal.minimumVotes,
            // newProposal.successOverRate,
            // newProposal.nameForOptionA,
            // newProposal.nameForOptionB
            newProposal.voteToken,
            newProposal.voteBlock,
            newProposal.proposalDeadline,
            newProposal.minimumVotes,
            newProposal.successOverRate,
            newProposal.nameForOptionA,
            newProposal.nameForOptionB
        );
    }

    function setVotePowerBatch(
        uint256 _proposalId,
        string[] memory _address,
        uint256[] memory _votingPower
    ) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp < proposal.proposalDeadline,
            "Proposal has expired"
        );
        require(!proposal.aborted, "Proposal already aborted");
        require(!proposal.executed, "Proposal already executed");
        require(_address.length != 0, "address is empty!");
        require(_votingPower.length != 0, "votingPower is empty!");
        require(
            _address.length == _votingPower.length,
            "array size not equal!"
        );

        uint256 arrLength = _address.length;
        uint256 setCnt = 0;
        for (uint256 index = 0; index < arrLength; index++) {
            string memory tempString = _address[index];
            uint256 tempPower = _votingPower[index];
            if (tempPower > 0) {
                address tempAddress = stringToAddress(tempString);
                if (!hasVoted[_proposalId][tempAddress]) {
                    VPower storage vpower = votingPower[_proposalId][
                        tempAddress
                    ];
                    if (!vpower.isSet) {
                        proposal.voterCount = proposal.voterCount + 1;
                        voterIndex[_proposalId][
                            proposal.voterCount
                        ] = tempAddress;
                        proposal.votingPowerSum += tempPower;
                        vpower.index = proposal.voterCount;
                        vpower.power = tempPower;
                        vpower.value = tempPower;
                        vpower.isSet = true;
                        setCnt++;
                    }
                }
            }
        }

        emit VotePowerBatch(_proposalId, setCnt);
    }

    function setVotePowerBatch2(
        uint256 _proposalId,
        address[] memory _address,
        uint256[] memory _votingPower
    ) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp < proposal.proposalDeadline,
            "Proposal has expired"
        );
        require(!proposal.aborted, "Proposal already aborted");
        require(!proposal.executed, "Proposal already executed");
        require(_address.length != 0, "address is empty!");
        require(_votingPower.length != 0, "votingPower is empty!");
        require(
            _address.length == _votingPower.length,
            "array size not equal!"
        );

        uint256 arrLength = _address.length;
        uint256 setCnt = 0;
        for (uint256 index = 0; index < arrLength; index++) {
            uint256 tempPower = _votingPower[index];
            if (tempPower > 0) {
                address tempAddress = _address[index];
                if (!hasVoted[_proposalId][tempAddress]) {
                    VPower storage vpower = votingPower[_proposalId][
                        tempAddress
                    ];
                    if (!vpower.isSet) {
                        proposal.voterCount = proposal.voterCount + 1;
                        voterIndex[_proposalId][
                            proposal.voterCount
                        ] = tempAddress;
                        proposal.votingPowerSum += tempPower;
                        vpower.index = proposal.voterCount;
                        vpower.power = tempPower;
                        vpower.value = tempPower;
                        vpower.isSet = true;
                        setCnt++;
                    }
                }
            }
        }

        emit VotePowerBatch(_proposalId, setCnt);
    }

    function setVotePower(
        uint256 _proposalId,
        address _voterAddress,
        uint256 _votePower
    ) public onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp < proposal.proposalDeadline,
            "Proposal has expired"
        );
        require(!proposal.aborted, "Proposal already aborted");
        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[_proposalId][_voterAddress], "Already voted");

        VPower storage vpower = votingPower[_proposalId][_voterAddress];
        require(!vpower.isSet, "Voting Power already set");
        require(_votePower > 0, "Voter has no voting power");

        proposal.voterCount = proposal.voterCount + 1;
        voterIndex[_proposalId][proposal.voterCount] = _voterAddress;
        proposal.votingPowerSum += _votePower;
        vpower.index = proposal.voterCount;
        vpower.power = _votePower;
        vpower.value = _votePower;
        vpower.isSet = true;

        //emit VotePower(_proposalId, msg.sender, _votePower);
        emit VotePower(_proposalId, _voterAddress, _votePower);
    }

    function vote(uint256 _proposalId, Option _selectedOption) public {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp < proposal.proposalDeadline,
            "Proposal has expired"
        );
        require(!proposal.aborted, "Proposal already aborted");
        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(
            _selectedOption == Option.A || _selectedOption == Option.B,
            "Invalid option"
        );

        //IERC20 voteToken = IERC20(proposal.voteToken);
        //uint256 votingPower = voteToken.balanceOf(msg.sender);
        VPower storage vpower = votingPower[_proposalId][msg.sender];
        require(vpower.isSet, "Voting Power is not set");
        require(vpower.power > 0, "Voter has no voting power");
        require(
            vpower.power >= proposal.minimumVotes,
            "Voting power is less than the minimum."
        );

        if (_selectedOption == Option.A) {
            proposal.votesForOptionA += vpower.power;
        } else {
            proposal.votesForOptionB += vpower.power;
        }

        hasVoted[_proposalId][msg.sender] = true;
        vpower.power = 0;

        emit VoteCasted(_proposalId, msg.sender, _selectedOption);
    }

    function executeProposal(uint256 _proposalId) public virtual onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp >= proposal.proposalDeadline,
            "Proposal deadline not yet reached"
        );
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.aborted, "Proposal already aborted");

        Winner memory winner;
        if (proposal.votesForOptionA > proposal.votesForOptionB) {
            if (
                proposal.votesForOptionA >=
                (proposal.votingPowerSum * proposal.successOverRate) / 100
            ) {
                winner.proposalId = _proposalId;
                winner.title = proposal.title;
                winner.nameForOption = proposal.nameForOptionA;

                winners[_proposalId] = winner;
                proposal.executed = true;
                proposal.isSuccess = true;
            } else {
                proposal.executed = true;
                proposal.isSuccess = false;
            }
        } else if (proposal.votesForOptionB > proposal.votesForOptionA) {
            if (
                proposal.votesForOptionB >=
                (proposal.votingPowerSum * proposal.successOverRate) / 100
            ) {
                winner.proposalId = _proposalId;
                winner.title = proposal.title;
                winner.nameForOption = proposal.nameForOptionB;

                winners[_proposalId] = winner;
                proposal.executed = true;
                proposal.isSuccess = true;
            } else {
                proposal.executed = true;
                proposal.isSuccess = false;
            }
        } else {
            // Handle tie case, if desired
            // revert("Tie not allowed");
            proposal.executed = true;
            proposal.isSuccess = false;
        }
    }

    function executeAbort(uint256 _proposalId) public virtual onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp < proposal.proposalDeadline,
            "Proposal has expired"
        );
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.aborted, "Proposal already aborted");

        proposal.aborted = true;
    }

    function getProposal(
        uint256 _proposalId
    )
        public
        view
        returns (
            // string memory title,
            // string memory description,
            // address voteToken,
            // uint256 voteBlock,
            // uint256 proposalDeadline,
            // uint256 votesForOptionA,
            // uint256 votesForOptionB,
            // uint256 minimumVotes,
            // uint256 voterCount,
            // uint256 votingPowerSum,
            // uint128 successOverRate,
            // string memory nameForOptionA,
            // string memory nameForOptionB,
            // string memory ipfsHash,
            // string memory ipfsFileName,
            // bool aborted,
            // bool executed,
            // bool isSuccess
            Proposal memory proposal
        )
    {
        return proposal = proposals[_proposalId];

        // title = proposal.title;
        // description = proposal.description;
        // voteToken = proposal.voteToken;
        // voteBlock = proposal.voteBlock;
        // proposalDeadline = proposal.proposalDeadline;
        // votesForOptionA = proposal.votesForOptionA;
        // votesForOptionB = proposal.votesForOptionB;
        // minimumVotes = proposal.minimumVotes;
        // voterCount = proposal.voterCount;
        // votingPowerSum = proposal.votingPowerSum;
        // successOverRate = proposal.successOverRate;
        // nameForOptionA = proposal.nameForOptionA;
        // nameForOptionB = proposal.nameForOptionB;
        // ipfsHash = proposal.ipfsHash;
        // ipfsFileName = proposal.ipfsFileName;
        // aborted = proposal.aborted;
        // executed = proposal.executed;
        // isSuccess = proposal.isSuccess;
    }

    function getWinner(
        uint256 _proposalId
    )
        public
        view
        returns (string memory winnerTitle, string memory winnerNameForOption)
    {
        Winner storage winner = winners[_proposalId];

        winnerTitle = winner.title;
        winnerNameForOption = winner.nameForOption;
    }

    function viewHasVoted(
        uint256 _proposalId,
        address _voter
    ) public view returns (bool) {
        require(_proposalId < proposalCounter, "Invalid proposal ID");
        return hasVoted[_proposalId][_voter];
    }

    function viewVotingPower(
        uint256 _proposalId,
        address _voter
    )
        public
        view
        returns (
            address voterAddress,
            uint256 index,
            bool isSet,
            uint256 value,
            uint256 power
        )
    {
        require(_proposalId < proposalCounter, "Invalid proposal ID");
        VPower storage vpower = votingPower[_proposalId][_voter];

        voterAddress = _voter;
        index = vpower.index;
        isSet = vpower.isSet;
        value = vpower.value;
        power = vpower.power;
    }

    function viewVotingPower2(
        uint256 _proposalId,
        uint256 _voterIndex
    )
        public
        view
        returns (
            address voterAddress,
            uint256 index,
            bool isSet,
            uint256 value,
            uint256 power
        )
    {
        require(_proposalId < proposalCounter, "Invalid proposal ID");
        VPower storage vpower = votingPower[_proposalId][
            voterIndex[_proposalId][_voterIndex]
        ];

        voterAddress = voterIndex[_proposalId][_voterIndex];
        index = vpower.index;
        isSet = vpower.isSet;
        value = vpower.value;
        power = vpower.power;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCounter;
    }

    function getVoterCount(uint256 _proposalId) public view returns (uint256) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.voterCount;
    }

    function stringToAddress(
        string memory _address
    ) public pure returns (address) {
        string memory cleanAddress = remove0xPrefix(_address);
        bytes20 _addressBytes = parseHexStringToBytes20(cleanAddress);
        return address(_addressBytes);
    }

    function remove0xPrefix(
        string memory _hexString
    ) internal pure returns (string memory) {
        if (
            bytes(_hexString).length >= 2 &&
            bytes(_hexString)[0] == "0" &&
            (bytes(_hexString)[1] == "x" || bytes(_hexString)[1] == "X")
        ) {
            return substring(_hexString, 2, bytes(_hexString).length);
        }
        return _hexString;
    }

    function substring(
        string memory _str,
        uint256 _start,
        uint256 _end
    ) internal pure returns (string memory) {
        bytes memory _strBytes = bytes(_str);
        bytes memory _result = new bytes(_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            _result[i - _start] = _strBytes[i];
        }
        return string(_result);
    }

    function parseHexStringToBytes20(
        string memory _hexString
    ) internal pure returns (bytes20) {
        bytes memory _bytesString = bytes(_hexString);
        uint160 _parsedBytes = 0;
        for (uint256 i = 0; i < _bytesString.length; i += 2) {
            _parsedBytes *= 256;
            uint8 _byteValue = parseByteToUint8(_bytesString[i]);
            _byteValue *= 16;
            _byteValue += parseByteToUint8(_bytesString[i + 1]);
            _parsedBytes += _byteValue;
        }
        return bytes20(_parsedBytes);
    }

    function parseByteToUint8(bytes1 _byte) internal pure returns (uint8) {
        if (uint8(_byte) >= 48 && uint8(_byte) <= 57) {
            return uint8(_byte) - 48;
        } else if (uint8(_byte) >= 65 && uint8(_byte) <= 70) {
            return uint8(_byte) - 55;
        } else if (uint8(_byte) >= 97 && uint8(_byte) <= 102) {
            return uint8(_byte) - 87;
        } else {
            revert(string(abi.encodePacked("Invalid byte value: ", _byte)));
        }
    }
}
