// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice A public voting system for new proposals.
contract VotingService is Ownable {
    struct Voter {
        /// To know if the voter is whitelisted.
        bool isRegistered;
        /// To know the voter already voted.
        bool hasVoted;
        /// To know which proposal the voter voted for.
        uint256 votedProposalId;
    }

    struct Proposal {
        /// Title that also desccribes the proposal
        string description;
        /// Number of votes received.
        uint256 voteCount;
    }

    /// Associates an address to each voter
    mapping(address => Voter) public voters;

    /// Stores the proposals.
    Proposal[] public proposals;

    /// Stores the ID of the most voted proposal.
    uint256 public winningProposalId = 0;

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
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    constructor() {
        /// Initiates workflow to whitelisting phase.
        workflowStatus = WorkflowStatus.RegisteringVoters;
    }

    /// @notice Allow address to participate in the proposal process as well as the voting process.
    /// @param _voter Address that is going to be authorized by the admin.
    function whitelistVoter(address _voter) public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.RegisteringVoters,
            "Too late to add a voter."
        );
        require(msg.sender != _voter, "The admin is not allowed to vote.");

        /// Adds the user's address to the whitelist.
        voters[_voter].isRegistered = true;

        emit VoterRegistered(_voter);
    }

    /// @notice Ensures the user can register a proposal and vote.
    modifier isWhitelisted() {
        require(
            voters[msg.sender].isRegistered,
            "You haven't been whitelisted."
        );
        _;
    }

    /// @notice Lets a whitelisted user register a new proposal.
    /// @param _description Name of the proposal.
    function registerProposal(string memory _description) public isWhitelisted {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Impossible to register a proposal now."
        );

        /// Use of the length of the array to know the new proposal ID.
        uint256 proposalId = proposals.length;

        /// Instantiates and adds the new proposal with 0 votes.
        Proposal memory proposal = Proposal(_description, 0);
        proposals.push(proposal);

        emit ProposalRegistered(proposalId);
    }

    /// @notice Lets a whitelisted user cast a vote to a proposal.
    /// @param _proposalId The ID of the proposal that is voted for.
    function voteForProposal(uint256 _proposalId) public isWhitelisted {
        require(
            workflowStatus == WorkflowStatus.VotingSessionStarted,
            "Impossible to vote for a proposal now."
        );
        require(!voters[msg.sender].hasVoted, "You already voted.");

        /// Increase the number of votes for the proposal by 1.
        proposals[_proposalId].voteCount++;

        /// Links the voter to the proposal he voted for.
        voters[msg.sender].votedProposalId = _proposalId;

        /// Restricts to one vote per voter.
        voters[msg.sender].hasVoted = true;

        emit Voted(msg.sender, _proposalId);
    }

    /// @notice Uses the number of votes to find which proposal wins.
    function countVotes() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionEnded,
            "Impossible to count votes now."
        );

        /// Initialize a variable meant to save the number of votes of the most voted proposal
        uint256 currentBest = 0;

        /// Loops through the proposals
        for (uint256 i = 0; i < proposals.length; i++) {
            /// If a proposal has more votes than the currently saved one, the number of votes is saved.
            if (proposals[i].voteCount > currentBest) {
                currentBest = proposals[i].voteCount;

                /// The ID is saved.
                winningProposalId = i;
            }
        }
    }

    /// @notice Shows details, name and number of votes for a given proposal.
    /// @return The proposal that had the most votes, in a struct format.
    function seeWinningProposalDetails() public view returns (Proposal memory) {
        require(
            workflowStatus == WorkflowStatus.VotesTallied,
            "Votes haven't been counted yet."
        );

        /// e.g. If the name of proposal is "prop1", and it has 2 votes, remix will show:
        /// 0: tuple(string,uint256): prop1,2
        return proposals[winningProposalId];
    }

    /// @notice Shows the number of votes for a given proposal.
    /// @param _proposalId The ID of the proposal inspected by the user.
    /// @return The vote count of the proposal.
    function seeProposalVoteCount(uint256 _proposalId)
        public
        view
        returns (uint256)
    {
        require(
            workflowStatus == WorkflowStatus.VotesTallied,
            "Votes haven't been counted yet."
        );

        return proposals[_proposalId].voteCount;
    }

    /// Functions related to the workflow

    /// @notice Starts proposal phase when called by the admin. Ends whitelisting phase.
    function startProposals() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.RegisteringVoters,
            "Too late to start proposals."
        );

        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    /// @notice Ends proposal phase when called by the admin.
    function endProposals() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Impossible to end proposals now."
        );

        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    /// @notice Starts voting phase when called by the admin.
    function startVotingSession() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationEnded,
            "Impossible to start the voting session now now."
        );

        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    /// @notice Ends voting phase when called by the admin. Starts vote tally phase.
    function endVotingSession() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionStarted,
            "Impossible to end the voting session now."
        );

        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    /// @notice Ends vote tally phase when called by the admin.
    function voteTallied() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionEnded,
            "Impossible to proceed to vote tally now."
        );

        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }
}
