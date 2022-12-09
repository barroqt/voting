// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: Timestamps?

/// @notice A public voting system for new proposals.
contract VotingService is Ownable {

    struct Voter {
        /// To know if the voter is whitelisted.
        bool isRegistered;

        /// To know the voter already voted.
        bool hasVoted;

        /// To know which proposal the voter voted for.
        uint votedProposalId;
    }

    struct Proposal {
        /// Title that also desccribes the proposal
        string description;

        /// Number of votes received.
        uint voteCount;
    }

    /// Associates an address to each voter
    mapping(address => Voter) public voters;

    /// Stores the proposals.
    Proposal[] public proposals;

    /// Stores the ID of the most voted proposal.
    uint public winningProposalId = 0;

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public workflowStatus;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    constructor() {
        /// Initiates workflow to whitelisting phase.
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    /// @notice Allow address to participate in the proposal process as well as the voting process.
    /// @param _voter Address that is going to be authorized by the admin.
    function whitelistVoter(address _voter) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Too late to add a voter.");
        require(msg.sender != _voter, "The admin is not allowed to vote.");

        /// Adds the user's address to the whitelist.
        voters[_voter].isRegistered = true;

        emit VoterRegistered(_voter);
    }

    /// @notice Registers a new proposal.
    /// @param _description Name of the proposal.
    function registerProposal(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Impossible to register a proposal now.");
        require(voters[msg.sender].isRegistered, "You haven't been whitelisted.");

        /// Use of the length of the array to know the new proposal ID.
        uint proposalId = proposals.length;

        /// Instantiates and adds the new proposal with 0 votes.
        Proposal memory proposal = Proposal(_description, 0);
        proposals.push(proposal);

        emit ProposalRegistered(proposalId);
    }

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    /// @param _proposalId The ID of the proposal that is voted for.
    function voteForProposal(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Impossible to vote for a proposal now.");
        require(voters[msg.sender].isRegistered, "You haven't been whitelisted.");
        require(!voters[msg.sender].hasVoted, "You already voted.");

        /// Increase the number of votes for the proposal by 1.
        proposals[_proposalId].voteCount++;

        /// Links the voter to the proposal he voted for.
        voters[msg.sender].votedProposalId = _proposalId;

        /// Restricts to one vote per voter.
        voters[msg.sender].hasVoted = true;

        emit Voted (msg.sender, _proposalId);
    }

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    function countVotes() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Impossible to count votes now.");

        /// Initialize a variable meant to save the number of votes of the most voted proposal
        uint currentBest = 0;

        /// Loops through the proposals
        for(uint i = 0; i < proposals.length; i++) {

            /// If a proposal has more votes than the currently saved one, the number of votes is saved. 
            if (proposals[i].voteCount > currentBest) {
                currentBest = proposals[i].voteCount;

                /// The ID is saved.
                winningProposalId = i;
            }
        }
    }

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    /// @return The proposal that had the most votes, in a struct format.
    function seeWinningProposalDetails() public view returns (Proposal memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Votes haven't been counted yet.");
        
        /// e.g. If proposal with ID 0 wins, name of proposal "prop1", and 2 votes, remix will show: 
        /// 0: tuple(string,uint256): prop1,2
        return proposals[winningProposalId];
    }

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    /// @param _proposalId The ID of the proposal inspected by the user.
    /// @return The vote count of the proposal.
    function seeProposalVoteCount(uint _proposalId) public view returns (uint) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Votes haven't been counted yet.");
        
        return proposals[_proposalId].voteCount;
    }

    /// Functions related to the workflow 

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    function startProposals() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Too late to start proposals.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /// @notice Ends proposal phase when called by the admin.
    function endProposals() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Impossible to end proposals now.");

        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /// @notice Starts voting phase when called by the admin.
    function startVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Impossible to start the voting session now now.");

        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /// @notice Ends voting phase when called by the admin. Starts vote tally phase.
    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Impossible to end the voting session now.");

        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /// @notice Ends vote tally phase when called by the admin.
    function voteTallied() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Impossible to proceed to vote tally now.");

        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }
}