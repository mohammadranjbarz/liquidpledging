pragma solidity ^0.4.24;

import "./ILiquidPledgingPlugin.sol";
import "./ILPVault.sol";


/// This contract contains all state variables used in LiquidPledging contracts
/// This is done to have everything in 1 location, b/c state variable layout
/// MUST be the same when performing an upgrade.
contract LiquidPledgingStorage {
    enum PledgeAdminType { Giver, Delegate, Project }
    enum PledgeState { Pledged, Paying, Paid }

    /// @dev This struct defines the details of a `PledgeAdmin` which are 
    ///  commonly referenced by their index in the `admins` array
    ///  and can own pledges and act as delegates
    struct PledgeAdmin { 
        PledgeAdminType adminType; // Giver, Delegate or Project
        address addr; // Account or contract address for admin
        uint64 commitTime;  // In seconds, used for time Givers' & Delegates' have to veto
        uint64 parentProject;  // Only for projects
        bool canceled;      //Always false except for canceled projects

        /// @dev if the plugin is 0x0 then nothing happens, if its an address
        // than that smart contract is called when appropriate
        ILiquidPledgingPlugin plugin; 
        string name;
        string url;  // Can be IPFS hash
    }

    struct Pledge {
        uint amount;
        uint64[] delegationChain; // List of delegates in order of authority
        uint64 owner; // PledgeAdmin
        uint64 intendedProject; // Used when delegates are sending to projects
        uint64 commitTime;  // When the intendedProject will become the owner
        uint64 oldPledge; // Points to the id that this Pledge was derived from
        address token;
        PledgeState pledgeState; //  Pledged, Paying, Paid
    }

    PledgeAdmin[] admins; //The list of pledgeAdmins 0 means there is no admin
    Pledge[] pledges;
    /// @dev this mapping allows you to search for a specific pledge's 
    ///  index number by the hash of that pledge
    mapping (bytes32 => uint64) hPledge2idx;

    // this whitelist is for non-proxied plugins
    mapping (bytes32 => bool) pluginContractWhitelist;
    // this whitelist is for proxied plugins
    mapping (address => bool) pluginInstanceWhitelist;
    bool public whitelistDisabled = false;

    ILPVault public vault;
}