// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/ownership/Ownable.sol';

contract VotingService is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public workflowStatus;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    uint public winningProposalId = 0;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    constructor() public {
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    function whitelistVoter(address _voter) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Too late to add a voter.");

        voters[_voter].isRegistered = true;
        emit VoterRegistered(_voter);
    }

    // function generateRandomId() private view returns(uint) {
    //     return uint(keccak256(block.difficulty, now, voters));
    // }

    function registerProposal(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Impossible to register a proposal now.");
        require(voters[msg.sender].isRegistered, "You haven't been whitelisted.");

        uint proposalId = proposals.length;
        Proposal memory proposal = Proposal(_description, 0);

        voters[msg.sender].votedProposalId = proposalId;
        proposals.push(proposal);
        emit ProposalRegistered(proposalId);
    }

    function voteForProposal(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Impossible to vote for a proposal now.");
        require(voters[msg.sender].isRegistered, "You haven't been whitelisted.");
        require(!voters[msg.sender].hasVoted, "You already voted.");

        proposals[_proposalId].voteCount++;
        voters[msg.sender].votedProposalId = _proposalId;
        voters[msg.sender].hasVoted = true;
        emit Voted (msg.sender, _proposalId);
    }

    function voteTally() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Impossible to count votes now.");
        
        uint currentBest = 0;
        for(uint i = 0; proposals.length; i++) {
            if (proposals[i].voteCount > currentBest) {
                currentBest = proposals[i].voteCount;
                winningProposalId = i;
            }
        }
    }

    function seeWinningProposalDetails() public view returns (Proposal) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Votes haven't been counted yet.");
        
        return proposals[winningProposalId];
    }

    // Functions related to the workflow
    function startProposals() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Too late to start proposals.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function endProposals() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Impossible to end proposals now.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Impossible to start the voting session now now.");

        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Impossible to end the voting session now.");

        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function startVoteTally() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Impossible to proceed to vote tally now.");

        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }
}