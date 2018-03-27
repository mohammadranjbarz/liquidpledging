

///File: ./contracts/ILiquidPledgingPlugin.sol

pragma solidity ^0.4.11;

/*
    Copyright 2017, Jordi Baylina
    Contributors: Adrià Massanet <adria@codecontext.io>, RJ Ewing, Griff
    Green, Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


/// @dev `ILiquidPledgingPlugin` is the basic interface for any
///  liquid pledging plugin
contract ILiquidPledgingPlugin {

    /// @notice Plugins are used (much like web hooks) to initiate an action
    ///  upon any donation, delegation, or transfer; this is an optional feature
    ///  and allows for extreme customization of the contract. This function
    ///  implements any action that should be initiated before a transfer.
    /// @param pledgeManager The admin or current manager of the pledge
    /// @param pledgeFrom This is the Id from which value will be transfered.
    /// @param pledgeTo This is the Id that value will be transfered to.    
    /// @param context The situation that is triggering the plugin:
    ///  0 -> Plugin for the owner transferring pledge to another party
    ///  1 -> Plugin for the first delegate transferring pledge to another party
    ///  2 -> Plugin for the second delegate transferring pledge to another party
    ///  ...
    ///  255 -> Plugin for the intendedProject transferring pledge to another party
    ///
    ///  256 -> Plugin for the owner receiving pledge to another party
    ///  257 -> Plugin for the first delegate receiving pledge to another party
    ///  258 -> Plugin for the second delegate receiving pledge to another party
    ///  ...
    ///  511 -> Plugin for the intendedProject receiving pledge to another party
    /// @param amount The amount of value that will be transfered.
    function beforeTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount ) public returns (uint maxAllowed);

    /// @notice Plugins are used (much like web hooks) to initiate an action
    ///  upon any donation, delegation, or transfer; this is an optional feature
    ///  and allows for extreme customization of the contract. This function
    ///  implements any action that should be initiated after a transfer.
    /// @param pledgeManager The admin or current manager of the pledge
    /// @param pledgeFrom This is the Id from which value will be transfered.
    /// @param pledgeTo This is the Id that value will be transfered to.    
    /// @param context The situation that is triggering the plugin:
    ///  0 -> Plugin for the owner transferring pledge to another party
    ///  1 -> Plugin for the first delegate transferring pledge to another party
    ///  2 -> Plugin for the second delegate transferring pledge to another party
    ///  ...
    ///  255 -> Plugin for the intendedProject transferring pledge to another party
    ///
    ///  256 -> Plugin for the owner receiving pledge to another party
    ///  257 -> Plugin for the first delegate receiving pledge to another party
    ///  258 -> Plugin for the second delegate receiving pledge to another party
    ///  ...
    ///  511 -> Plugin for the intendedProject receiving pledge to another party
    ///  @param amount The amount of value that will be transfered.
    function afterTransfer(
        uint64 pledgeManager,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) public;
}


///File: ./contracts/LiquidPledgingStorage.sol

pragma solidity ^0.4.18;



/// @dev This is an interface for `LPVault` which serves as a secure storage for
///  the ETH that backs the Pledges, only after `LiquidPledging` authorizes
///  payments can Pledges be converted for ETH
interface ILPVault {
    function authorizePayment(bytes32 _ref, address _dest, address _token, uint _amount) public;
}

/// This contract contains all state variables used in LiquidPledging contracts
/// This is done to have everything in 1 location, b/c state variable layout
/// is MUST have be the same when performing an upgrade.
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

    // reserve 50 slots for future upgrades. I'm not sure if this is necessary 
    // but b/c of multiple inheritance used in lp, better safe then sorry.
    // especially since it is free
    uint[50] private storageOffset;
}

///File: @aragon/os/contracts/acl/IACL.sol

pragma solidity ^0.4.18;


interface IACL {
    function initialize(address permissionsCreator) public;
    function hasPermission(address who, address where, bytes32 what, bytes how) public view returns (bool);
}


///File: @aragon/os/contracts/kernel/IKernel.sol

pragma solidity ^0.4.18;



interface IKernel {
    event SetApp(bytes32 indexed namespace, bytes32 indexed name, bytes32 indexed id, address app);

    function acl() public view returns (IACL);
    function hasPermission(address who, address where, bytes32 what, bytes how) public view returns (bool);

    function setApp(bytes32 namespace, bytes32 name, address app) public returns (bytes32 id);
    function getApp(bytes32 id) public view returns (address);
}

///File: @aragon/os/contracts/apps/AppStorage.sol

pragma solidity ^0.4.18;




contract AppStorage {
    IKernel public kernel;
    bytes32 public appId;
    address internal pinnedCode; // used by Proxy Pinned
    uint256 internal initializationBlock; // used by Initializable
    uint256[95] private storageOffset; // forces App storage to start at after 100 slots
    uint256 private offset;
}


///File: @aragon/os/contracts/common/Initializable.sol

pragma solidity ^0.4.18;




contract Initializable is AppStorage {
    modifier onlyInit {
        require(initializationBlock == 0);
        _;
    }

    /**
    * @return Block number in which the contract was initialized
    */
    function getInitializationBlock() public view returns (uint256) {
        return initializationBlock;
    }

    /**
    * @dev Function to be called by top level contract after initialization has finished.
    */
    function initialized() internal onlyInit {
        initializationBlock = getBlockNumber();
    }

    /**
    * @dev Returns the current block number.
    *      Using a function rather than `block.number` allows us to easily mock the block number in
    *      tests.
    */
    function getBlockNumber() internal view returns (uint256) {
        return block.number;
    }
}


///File: @aragon/os/contracts/evmscript/IEVMScriptExecutor.sol

pragma solidity ^0.4.18;


interface IEVMScriptExecutor {
    function execScript(bytes script, bytes input, address[] blacklist) external returns (bytes);
}


///File: @aragon/os/contracts/evmscript/IEVMScriptRegistry.sol

pragma solidity 0.4.18;


contract EVMScriptRegistryConstants {
    bytes32 constant public EVMSCRIPT_REGISTRY_APP_ID = keccak256("evmreg.aragonpm.eth");
    bytes32 constant public EVMSCRIPT_REGISTRY_APP = keccak256(keccak256("app"), EVMSCRIPT_REGISTRY_APP_ID);
}


interface IEVMScriptRegistry {
    function addScriptExecutor(address executor) external returns (uint id);
    function disableScriptExecutor(uint256 executorId) external;

    function getScriptExecutor(bytes script) public view returns (address);
}

///File: @aragon/os/contracts/evmscript/ScriptHelpers.sol

pragma solidity 0.4.18;


library ScriptHelpers {
    // To test with JS and compare with actual encoder. Maintaining for reference.
    // t = function() { return IEVMScriptExecutor.at('0x4bcdd59d6c77774ee7317fc1095f69ec84421e49').contract.execScript.getData(...[].slice.call(arguments)).slice(10).match(/.{1,64}/g) }
    // run = function() { return ScriptHelpers.new().then(sh => { sh.abiEncode.call(...[].slice.call(arguments)).then(a => console.log(a.slice(2).match(/.{1,64}/g)) ) }) }
    // This is truly not beautiful but lets no daydream to the day solidity gets reflection features

    function abiEncode(bytes _a, bytes _b, address[] _c) public pure returns (bytes d) {
        return encode(_a, _b, _c);
    }

    function encode(bytes memory _a, bytes memory _b, address[] memory _c) internal pure returns (bytes memory d) {
        // A is positioned after the 3 position words
        uint256 aPosition = 0x60;
        uint256 bPosition = aPosition + 32 * abiLength(_a);
        uint256 cPosition = bPosition + 32 * abiLength(_b);
        uint256 length = cPosition + 32 * abiLength(_c);

        d = new bytes(length);
        assembly {
            // Store positions
            mstore(add(d, 0x20), aPosition)
            mstore(add(d, 0x40), bPosition)
            mstore(add(d, 0x60), cPosition)
        }

        // Copy memory to correct position
        copy(d, getPtr(_a), aPosition, _a.length);
        copy(d, getPtr(_b), bPosition, _b.length);
        copy(d, getPtr(_c), cPosition, _c.length * 32); // 1 word per address
    }

    function abiLength(bytes memory _a) internal pure returns (uint256) {
        // 1 for length +
        // memory words + 1 if not divisible for 32 to offset word
        return 1 + (_a.length / 32) + (_a.length % 32 > 0 ? 1 : 0);
    }

    function abiLength(address[] _a) internal pure returns (uint256) {
        // 1 for length + 1 per item
        return 1 + _a.length;
    }

    function copy(bytes _d, uint256 _src, uint256 _pos, uint256 _length) internal pure {
        uint dest;
        assembly {
            dest := add(add(_d, 0x20), _pos)
        }
        memcpy(dest, _src, _length + 32);
    }

    function getPtr(bytes memory _x) internal pure returns (uint256 ptr) {
        assembly {
            ptr := _x
        }
    }

    function getPtr(address[] memory _x) internal pure returns (uint256 ptr) {
        assembly {
            ptr := _x
        }
    }

    function getSpecId(bytes _script) internal pure returns (uint32) {
        return uint32At(_script, 0);
    }

    function uint256At(bytes _data, uint256 _location) internal pure returns (uint256 result) {
        assembly {
            result := mload(add(_data, add(0x20, _location)))
        }
    }

    function addressAt(bytes _data, uint256 _location) internal pure returns (address result) {
        uint256 word = uint256At(_data, _location);

        assembly {
            result := div(and(word, 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000),
            0x1000000000000000000000000)
        }
    }

    function uint32At(bytes _data, uint256 _location) internal pure returns (uint32 result) {
        uint256 word = uint256At(_data, _location);

        assembly {
            result := div(and(word, 0xffffffff00000000000000000000000000000000000000000000000000000000),
            0x100000000000000000000000000000000000000000000000000000000)
        }
    }

    function locationOf(bytes _data, uint256 _location) internal pure returns (uint256 result) {
        assembly {
            result := add(_data, add(0x20, _location))
        }
    }

    function toBytes(bytes4 _sig) internal pure returns (bytes) {
        bytes memory payload = new bytes(4);
        payload[0] = bytes1(_sig);
        payload[1] = bytes1(_sig << 8);
        payload[2] = bytes1(_sig << 16);
        payload[3] = bytes1(_sig << 24);
        return payload;
    }

    function memcpy(uint _dest, uint _src, uint _len) public pure {
        uint256 src = _src;
        uint256 dest = _dest;
        uint256 len = _len;

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}

///File: @aragon/os/contracts/evmscript/EVMScriptRunner.sol

pragma solidity ^0.4.18;








contract EVMScriptRunner is AppStorage, EVMScriptRegistryConstants {
    using ScriptHelpers for bytes;

    function runScript(bytes _script, bytes _input, address[] _blacklist) protectState internal returns (bytes output) {
        // TODO: Too much data flying around, maybe extracting spec id here is cheaper
        address executorAddr = getExecutor(_script);
        require(executorAddr != address(0));

        bytes memory calldataArgs = _script.encode(_input, _blacklist);
        bytes4 sig = IEVMScriptExecutor(0).execScript.selector;

        require(executorAddr.delegatecall(sig, calldataArgs));

        return returnedDataDecoded();
    }

    function getExecutor(bytes _script) public view returns (IEVMScriptExecutor) {
        return IEVMScriptExecutor(getExecutorRegistry().getScriptExecutor(_script));
    }

    // TODO: Internal
    function getExecutorRegistry() internal view returns (IEVMScriptRegistry) {
        address registryAddr = kernel.getApp(EVMSCRIPT_REGISTRY_APP);
        return IEVMScriptRegistry(registryAddr);
    }

    /**
    * @dev copies and returns last's call data. Needs to ABI decode first
    */
    function returnedDataDecoded() internal view returns (bytes ret) {
        assembly {
            let size := returndatasize
            switch size
            case 0 {}
            default {
                ret := mload(0x40) // free mem ptr get
                mstore(0x40, add(ret, add(size, 0x20))) // free mem ptr set
                returndatacopy(ret, 0x20, sub(size, 0x20)) // copy return data
            }
        }
        return ret;
    }

    modifier protectState {
        address preKernel = kernel;
        bytes32 preAppId = appId;
        _; // exec
        require(kernel == preKernel);
        require(appId == preAppId);
    }
}

///File: @aragon/os/contracts/acl/ACLSyntaxSugar.sol

pragma solidity 0.4.18;


contract ACLSyntaxSugar {
    function arr() internal pure returns (uint256[] r) {}

    function arr(bytes32 _a) internal pure returns (uint256[] r) {
        return arr(uint256(_a));
    }

    function arr(bytes32 _a, bytes32 _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a) internal pure returns (uint256[] r) {
        return arr(uint256(_a));
    }

    function arr(address _a, address _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a, uint256 _b, uint256 _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), _b, _c);
    }

    function arr(address _a, uint256 _b) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b));
    }

    function arr(address _a, address _b, uint256 _c, uint256 _d, uint256 _e) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), _c, _d, _e);
    }

    function arr(address _a, address _b, address _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), uint256(_c));
    }

    function arr(address _a, address _b, uint256 _c) internal pure returns (uint256[] r) {
        return arr(uint256(_a), uint256(_b), uint256(_c));
    }

    function arr(uint256 _a) internal pure returns (uint256[] r) {
        r = new uint256[](1);
        r[0] = _a;
    }

    function arr(uint256 _a, uint256 _b) internal pure returns (uint256[] r) {
        r = new uint256[](2);
        r[0] = _a;
        r[1] = _b;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c) internal pure returns (uint256[] r) {
        r = new uint256[](3);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c, uint256 _d) internal pure returns (uint256[] r) {
        r = new uint256[](4);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
        r[3] = _d;
    }

    function arr(uint256 _a, uint256 _b, uint256 _c, uint256 _d, uint256 _e) internal pure returns (uint256[] r) {
        r = new uint256[](5);
        r[0] = _a;
        r[1] = _b;
        r[2] = _c;
        r[3] = _d;
        r[4] = _e;
    }
}


contract ACLHelpers {
    function decodeParamOp(uint256 _x) internal pure returns (uint8 b) {
        return uint8(_x >> (8 * 30));
    }

    function decodeParamId(uint256 _x) internal pure returns (uint8 b) {
        return uint8(_x >> (8 * 31));
    }

    function decodeParamsList(uint256 _x) internal pure returns (uint32 a, uint32 b, uint32 c) {
        a = uint32(_x);
        b = uint32(_x >> (8 * 4));
        c = uint32(_x >> (8 * 8));
    }
}


///File: @aragon/os/contracts/apps/AragonApp.sol

pragma solidity ^0.4.18;







contract AragonApp is AppStorage, Initializable, ACLSyntaxSugar, EVMScriptRunner {
    modifier auth(bytes32 _role) {
        require(canPerform(msg.sender, _role, new uint256[](0)));
        _;
    }

    modifier authP(bytes32 _role, uint256[] params) {
        require(canPerform(msg.sender, _role, params));
        _;
    }

    function canPerform(address _sender, bytes32 _role, uint256[] params) public view returns (bool) {
        bytes memory how; // no need to init memory as it is never used
        if (params.length > 0) {
            uint256 byteLength = params.length * 32;
            assembly {
                how := params // forced casting
                mstore(how, byteLength)
            }
        }
        return address(kernel) == 0 || kernel.hasPermission(_sender, address(this), _role, how);
    }
}


///File: ./contracts/LiquidPledgingACLHelpers.sol

pragma solidity ^0.4.18;

contract LiquidPledgingACLHelpers {
    function arr(uint64 a, uint64 b, address c, uint d, address e) internal pure returns(uint[] r) {
        r = new uint[](4);
        r[0] = uint(a);
        r[1] = uint(b);
        r[2] = uint(c);
        r[3] = d;
        r[4] = uint(e);
    }

    function arr(bool a) internal pure returns (uint[] r) {
        r = new uint[](1);
        uint _a;
        assembly {
            _a := a // forced casting
        }
        r[0] = _a;
    }
}

///File: ./contracts/LiquidPledgingPlugins.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/





contract LiquidPledgingPlugins is AragonApp, LiquidPledgingStorage, LiquidPledgingACLHelpers {

    bytes32 constant public PLUGIN_MANAGER_ROLE = keccak256("PLUGIN_MANAGER_ROLE");

    function addValidPluginInstance(address addr) auth(PLUGIN_MANAGER_ROLE) public {
        pluginInstanceWhitelist[addr] = true;
    }

    function addValidPluginContract(bytes32 contractHash) auth(PLUGIN_MANAGER_ROLE) public {
        pluginContractWhitelist[contractHash] = true;
    }

    function addValidPluginContracts(bytes32[] contractHashes) external auth(PLUGIN_MANAGER_ROLE) {
        for (uint8 i = 0; i < contractHashes.length; i++) {
            addValidPluginContract(contractHashes[i]);
        }
    }

    function removeValidPluginContract(bytes32 contractHash) external authP(PLUGIN_MANAGER_ROLE, arr(contractHash)) {
        pluginContractWhitelist[contractHash] = false;
    }

    function removeValidPluginInstance(address addr) external auth(PLUGIN_MANAGER_ROLE) {
        pluginInstanceWhitelist[addr] = false;
    }

    function useWhitelist(bool useWhitelist) external auth(PLUGIN_MANAGER_ROLE) {
        whitelistDisabled = !useWhitelist;
    }

    function isValidPlugin(address addr) public view returns(bool) {
        if (whitelistDisabled || addr == 0x0) {
            return true;
        }

        // first check pluginInstances
        if (pluginInstanceWhitelist[addr]) {
            return true;
        }

        // if the addr isn't a valid instance, check the contract code
        bytes32 contractHash = getCodeHash(addr);

        return pluginContractWhitelist[contractHash];
    }

    function getCodeHash(address addr) public view returns(bytes32) {
        bytes memory o_code;
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            mstore(o_code, size) // store length in memory
            // actually retrieve the code, this needs assembly
            extcodecopy(addr, add(o_code, 0x20), 0, size)
        }
        return keccak256(o_code);
    }
}

///File: ./contracts/PledgeAdmins.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/



contract PledgeAdmins is AragonApp, LiquidPledgingPlugins {

    // Limits inserted to prevent large loops that could prevent canceling
    uint constant MAX_SUBPROJECT_LEVEL = 20;
    uint constant MAX_INTERPROJECT_LEVEL = 20;

    // Events
    event GiverAdded(uint64 indexed idGiver);
    event GiverUpdated(uint64 indexed idGiver);
    event DelegateAdded(uint64 indexed idDelegate);
    event DelegateUpdated(uint64 indexed idDelegate);
    event ProjectAdded(uint64 indexed idProject);
    event ProjectUpdated(uint64 indexed idProject);

////////////////////
// Public functions
////////////////////

    /// @notice Creates a Giver Admin with the `msg.sender` as the Admin address
    /// @param name The name used to identify the Giver
    /// @param url The link to the Giver's profile often an IPFS hash
    /// @param commitTime The length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    /// @param plugin This is Giver's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idGiver The id number used to reference this Admin
    function addGiver(
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) public returns (uint64 idGiver)
    {
        return addGiver(
            msg.sender,
            name,
            url,
            commitTime,
            plugin
        );
    }

    // TODO: is there an issue w/ allowing anyone to create a giver on behalf of another addy?
    function addGiver(
        address addr,
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) public returns (uint64 idGiver)
    {
        require(isValidPlugin(plugin)); // Plugin check

        idGiver = uint64(admins.length);

        // Save the fields
        admins.push(
            PledgeAdmin(
                PledgeAdminType.Giver,
                addr,
                commitTime,
                0,
                false,
                plugin,
                name,
                url)
        );

        GiverAdded(idGiver);
    }

    /// @notice Updates a Giver's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin, and it must be called
    ///  by the current address of the Giver
    /// @param idGiver This is the Admin id number used to specify the Giver
    /// @param newAddr The new address that represents this Giver
    /// @param newName The new name used to identify the Giver
    /// @param newUrl The new link to the Giver's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    function updateGiver(
        uint64 idGiver,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) public
    {
        PledgeAdmin storage giver = _findAdmin(idGiver);
        require(msg.sender == giver.addr);
        require(giver.adminType == PledgeAdminType.Giver); // Must be a Giver
        giver.addr = newAddr;
        giver.name = newName;
        giver.url = newUrl;
        giver.commitTime = newCommitTime;

        GiverUpdated(idGiver);
    }

    /// @notice Creates a Delegate Admin with the `msg.sender` as the Admin addr
    /// @param name The name used to identify the Delegate
    /// @param url The link to the Delegate's profile often an IPFS hash
    /// @param commitTime Sets the length of time in seconds that this delegate
    ///  can be vetoed. Whenever this delegate is in a delegate chain the time
    ///  allowed to veto any event must be greater than or equal to this time.
    /// @param plugin This is Delegate's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idxDelegate The id number used to reference this Delegate within
    ///  the PLEDGE_ADMIN array
    function addDelegate(
        string name,
        string url,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) public returns (uint64 idDelegate) 
    {
        require(isValidPlugin(plugin)); // Plugin check

        idDelegate = uint64(admins.length);

        admins.push(
            PledgeAdmin(
                PledgeAdminType.Delegate,
                msg.sender,
                commitTime,
                0,
                false,
                plugin,
                name,
                url)
        );

        DelegateAdded(idDelegate);
    }

    /// @notice Updates a Delegate's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin, and it must be called
    ///  by the current address of the Delegate
    /// @param idDelegate The Admin id number used to specify the Delegate
    /// @param newAddr The new address that represents this Delegate
    /// @param newName The new name used to identify the Delegate
    /// @param newUrl The new link to the Delegate's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds that this
    ///  delegate can be vetoed. Whenever this delegate is in a delegate chain
    ///  the time allowed to veto any event must be greater than or equal to
    ///  this time.
    function updateDelegate(
        uint64 idDelegate,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) public
    {
        PledgeAdmin storage delegate = _findAdmin(idDelegate);
        require(msg.sender == delegate.addr);
        require(delegate.adminType == PledgeAdminType.Delegate);
        delegate.addr = newAddr;
        delegate.name = newName;
        delegate.url = newUrl;
        delegate.commitTime = newCommitTime;

        DelegateUpdated(idDelegate);
    }

    /// @notice Creates a Project Admin with the `msg.sender` as the Admin addr
    /// @param name The name used to identify the Project
    /// @param url The link to the Project's profile often an IPFS hash
    /// @param projectAdmin The address for the trusted project manager
    /// @param parentProject The Admin id number for the parent project or 0 if
    ///  there is no parentProject
    /// @param commitTime Sets the length of time in seconds the Project has to
    ///   veto when the Project delegates to another Delegate and they pledge
    ///   those funds to a project
    /// @param plugin This is Project's liquid pledge plugin allowing for
    ///  extended functionality
    /// @return idProject The id number used to reference this Admin
    function addProject(
        string name,
        string url,
        address projectAdmin,
        uint64 parentProject,
        uint64 commitTime,
        ILiquidPledgingPlugin plugin
    ) public returns (uint64 idProject) 
    {
        require(isValidPlugin(plugin));

        if (parentProject != 0) {
            PledgeAdmin storage a = _findAdmin(parentProject);
            // getProjectLevel will check that parentProject has a `Project` adminType
            require(_getProjectLevel(a) < MAX_SUBPROJECT_LEVEL);
        }

        idProject = uint64(admins.length);

        admins.push(
            PledgeAdmin(
                PledgeAdminType.Project,
                projectAdmin,
                commitTime,
                parentProject,
                false,
                plugin,
                name,
                url)
        );

        ProjectAdded(idProject);
    }

    /// @notice Updates a Project's info to change the address, name, url, or
    ///  commitTime, it cannot be used to change a plugin or a parentProject,
    ///  and it must be called by the current address of the Project
    /// @param idProject The Admin id number used to specify the Project
    /// @param newAddr The new address that represents this Project
    /// @param newName The new name used to identify the Project
    /// @param newUrl The new link to the Project's profile often an IPFS hash
    /// @param newCommitTime Sets the length of time in seconds the Project has
    ///  to veto when the Project delegates to a Delegate and they pledge those
    ///  funds to a project
    function updateProject(
        uint64 idProject,
        address newAddr,
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) public
    {
        PledgeAdmin storage project = _findAdmin(idProject);

        require(msg.sender == project.addr);
        require(project.adminType == PledgeAdminType.Project);

        project.addr = newAddr;
        project.name = newName;
        project.url = newUrl;
        project.commitTime = newCommitTime;

        ProjectUpdated(idProject);
    }

/////////////////////////////
// Public constant functions
/////////////////////////////

    /// @notice A constant getter used to check how many total Admins exist
    /// @return The total number of admins (Givers, Delegates and Projects) .
    function numberOfPledgeAdmins() public constant returns(uint) {
        return admins.length - 1;
    }

    /// @notice A constant getter to check the details of a specified Admin
    /// @return addr Account or contract address for admin
    /// @return name Name of the pledgeAdmin
    /// @return url The link to the Project's profile often an IPFS hash
    /// @return commitTime The length of time in seconds the Admin has to veto
    ///   when the Admin delegates to a Delegate and that Delegate pledges those
    ///   funds to a project
    /// @return parentProject The Admin id number for the parent project or 0
    ///  if there is no parentProject
    /// @return canceled 0 for Delegates & Givers, true if a Project has been
    ///  canceled
    /// @return plugin This is Project's liquidPledging plugin allowing for
    ///  extended functionality
    function getPledgeAdmin(uint64 idAdmin) public view returns (
        PledgeAdminType adminType,
        address addr,
        string name,
        string url,
        uint64 commitTime,
        uint64 parentProject,
        bool canceled,
        address plugin
    ) {
        PledgeAdmin storage a = _findAdmin(idAdmin);
        adminType = a.adminType;
        addr = a.addr;
        name = a.name;
        url = a.url;
        commitTime = a.commitTime;
        parentProject = a.parentProject;
        canceled = a.canceled;
        plugin = address(a.plugin);
    }

    /// @notice A getter to find if a specified Project has been canceled
    /// @param projectId The Admin id number used to specify the Project
    /// @return True if the Project has been canceled
    function isProjectCanceled(uint64 projectId)
        public constant returns (bool)
    {
        PledgeAdmin storage a = _findAdmin(projectId);

        if (a.adminType == PledgeAdminType.Giver) {
            return false;
        }

        assert(a.adminType == PledgeAdminType.Project);

        if (a.canceled) {
            return true;
        }
        if (a.parentProject == 0) {
            return false;
        }

        return isProjectCanceled(a.parentProject);
    }

///////////////////
// Internal methods
///////////////////

    /// @notice A getter to look up a Admin's details
    /// @param idAdmin The id for the Admin to lookup
    /// @return The PledgeAdmin struct for the specified Admin
    function _findAdmin(uint64 idAdmin) internal view returns (PledgeAdmin storage) {
        require(idAdmin < admins.length);
        return admins[idAdmin];
    }

    /// @notice Find the level of authority a specific Project has
    ///  using a recursive loop
    /// @param a The project admin being queried
    /// @return The level of authority a specific Project has
    function _getProjectLevel(PledgeAdmin a) internal returns(uint64) {
        assert(a.adminType == PledgeAdminType.Project);

        if (a.parentProject == 0) {
            return(1);
        }

        PledgeAdmin storage parent = _findAdmin(a.parentProject);
        return _getProjectLevel(parent) + 1;
    }
}

///File: ./contracts/Pledges.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
                  Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/




contract Pledges is AragonApp, LiquidPledgingStorage {

    // Limits inserted to prevent large loops that could prevent canceling
    uint constant MAX_DELEGATES = 10;

    // a constant for when a delegate is requested that is not in the system
    uint64 constant  NOTFOUND = 0xFFFFFFFFFFFFFFFF;

/////////////////////////////
// Public constant functions
////////////////////////////

    /// @notice A constant getter that returns the total number of pledges
    /// @return The total number of Pledges in the system
    function numberOfPledges() public view returns (uint) {
        return pledges.length - 1;
    }

    /// @notice A getter that returns the details of the specified pledge
    /// @param idPledge the id number of the pledge being queried
    /// @return the amount, owner, the number of delegates (but not the actual
    ///  delegates, the intendedProject (if any), the current commit time and
    ///  the previous pledge this pledge was derived from
    function getPledge(uint64 idPledge) public view returns(
        uint amount,
        uint64 owner,
        uint64 nDelegates,
        uint64 intendedProject,
        uint64 commitTime,
        uint64 oldPledge,
        address token,
        PledgeState pledgeState
    ) {
        Pledge memory p = _findPledge(idPledge);
        amount = p.amount;
        owner = p.owner;
        nDelegates = uint64(p.delegationChain.length);
        intendedProject = p.intendedProject;
        commitTime = p.commitTime;
        oldPledge = p.oldPledge;
        token = p.token;
        pledgeState = p.pledgeState;
    }


////////////////////
// Internal methods
////////////////////

    /// @notice This creates a Pledge with an initial amount of 0 if one is not
    ///  created already; otherwise it finds the pledge with the specified
    ///  attributes; all pledges technically exist, if the pledge hasn't been
    ///  created in this system yet it simply isn't in the hash array
    ///  hPledge2idx[] yet
    /// @param owner The owner of the pledge being looked up
    /// @param delegationChain The list of delegates in order of authority
    /// @param intendedProject The project this pledge will Fund after the
    ///  commitTime has passed
    /// @param commitTime The length of time in seconds the Giver has to
    ///   veto when the Giver's delegates Pledge funds to a project
    /// @param oldPledge This value is used to store the pledge the current
    ///  pledge was came from, and in the case a Project is canceled, the Pledge
    ///  will revert back to it's previous state
    /// @param state The pledge state: Pledged, Paying, or state
    /// @return The hPledge2idx index number
    function _findOrCreatePledge(
        uint64 owner,
        uint64[] delegationChain,
        uint64 intendedProject,
        uint64 commitTime,
        uint64 oldPledge,
        address token,
        PledgeState state
    ) internal returns (uint64)
    {
        bytes32 hPledge = keccak256(delegationChain, owner, intendedProject, commitTime, oldPledge, token, state);
        uint64 id = hPledge2idx[hPledge];
        if (id > 0) {
            return id;
        }

        id = uint64(pledges.length);
        hPledge2idx[hPledge] = id;
        pledges.push(
            Pledge(
                0,
                delegationChain,
                owner,
                intendedProject,
                commitTime,
                oldPledge,
                token,
                state
            )
        );
        return id;
    }

    /// @param idPledge the id of the pledge to load from storage
    /// @return The Pledge
    function _findPledge(uint64 idPledge) internal view returns(Pledge storage) {
        require(idPledge < pledges.length);
        return pledges[idPledge];
    }

    /// @notice A getter that searches the delegationChain for the level of
    ///  authority a specific delegate has within a Pledge
    /// @param p The Pledge that will be searched
    /// @param idDelegate The specified delegate that's searched for
    /// @return If the delegate chain contains the delegate with the
    ///  `admins` array index `idDelegate` this returns that delegates
    ///  corresponding index in the delegationChain. Otherwise it returns
    ///  the NOTFOUND constant
    function _getDelegateIdx(Pledge p, uint64 idDelegate) internal pure returns(uint64) {
        for (uint i = 0; i < p.delegationChain.length; i++) {
            if (p.delegationChain[i] == idDelegate) {
                return uint64(i);
            }
        }
        return NOTFOUND;
    }

    /// @notice A getter to find how many old "parent" pledges a specific Pledge
    ///  had using a self-referential loop
    /// @param p The Pledge being queried
    /// @return The number of old "parent" pledges a specific Pledge had
    function _getPledgeLevel(Pledge p) internal view returns(uint) {
        if (p.oldPledge == 0) {
            return 0;
        }
        Pledge storage oldP = _findPledge(p.oldPledge);
        return _getPledgeLevel(oldP) + 1; // a loop lookup
    }
}


///File: giveth-common-contracts/contracts/ERC20.sol

pragma solidity ^0.4.15;


/**
 * @title ERC20
 * @dev A standard interface for tokens.
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 */
contract ERC20 {
  
    /// @dev Returns the total token supply
    function totalSupply() public constant returns (uint256 supply);

    /// @dev Returns the account balance of the account with address _owner
    function balanceOf(address _owner) public constant returns (uint256 balance);

    /// @dev Transfers _value number of tokens to address _to
    function transfer(address _to, uint256 _value) public returns (bool success);

    /// @dev Transfers _value number of tokens from address _from to address _to
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    /// @dev Allows _spender to withdraw from the msg.sender's account up to the _value amount
    function approve(address _spender, uint256 _value) public returns (bool success);

    /// @dev Returns the amount which _spender is still allowed to withdraw from _owner
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}


///File: ./contracts/EscapableApp.sol

pragma solidity ^0.4.18;
/*
    Copyright 2016, Jordi Baylina
    Contributor: Adrià Massanet <adria@codecontext.io>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// import "./Owned.sol";




/// @dev `EscapableApp` is a base level contract; it creates an escape hatch
///  function that can be called in an
///  emergency that will allow designated addresses to send any ether or tokens
///  held in the contract to an `escapeHatchDestination` as long as they were
///  not blacklisted
contract EscapableApp is AragonApp {
    // warning whoever has this role can move all funds to the `escapeHatchDestination`
    bytes32 constant public ESCAPE_HATCH_CALLER_ROLE = keccak256("ESCAPE_HATCH_CALLER_ROLE");

    event EscapeHatchBlackistedToken(address token);
    event EscapeHatchCalled(address token, uint amount);

    address public escapeHatchDestination;
    mapping (address=>bool) private escapeBlacklist; // Token contract addresses
    uint[20] private storageOffset; // reserve 20 slots for future upgrades

    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract; if a neutral address
    ///  is required, the WHG Multisig is an option:
    ///  0x8Ff920020c8AD673661c8117f2855C384758C572 
    function initialize(address _escapeHatchDestination) onlyInit public {
        initialized();
        require(_escapeHatchDestination != 0x0);

        escapeHatchDestination = _escapeHatchDestination;
    }

    /// @notice The `escapeHatch()` should only be called as a last resort if a
    /// security issue is uncovered or something unexpected happened
    /// @param _token to transfer, use 0x0 for ether
    function escapeHatch(address _token) public authP(ESCAPE_HATCH_CALLER_ROLE, arr(_token)) {
        require(escapeBlacklist[_token]==false);

        uint256 balance;

        /// @dev Logic for ether
        if (_token == 0x0) {
            balance = this.balance;
            escapeHatchDestination.transfer(balance);
            EscapeHatchCalled(_token, balance);
            return;
        }
        /// @dev Logic for tokens
        ERC20 token = ERC20(_token);
        balance = token.balanceOf(this);
        require(token.transfer(escapeHatchDestination, balance));
        EscapeHatchCalled(_token, balance);
    }

    /// @notice Checks to see if `_token` is in the blacklist of tokens
    /// @param _token the token address being queried
    /// @return False if `_token` is in the blacklist and can't be taken out of
    ///  the contract via the `escapeHatch()`
    function isTokenEscapable(address _token) constant public returns (bool) {
        return !escapeBlacklist[_token];
    }

    /// @notice Creates the blacklist of tokens that are not able to be taken
    ///  out of the contract; can only be done at the deployment, and the logic
    ///  to add to the blacklist will be in the constructor of a child contract
    /// @param _token the token contract address that is to be blacklisted 
    function _blacklistEscapeToken(address _token) internal {
        escapeBlacklist[_token] = true;
        EscapeHatchBlackistedToken(_token);
    }
}


///File: ./contracts/LiquidPledgingBase.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina
    Contributors: Adrià Massanet <adria@codecontext.io>, RJ Ewing, Griff
    Green, Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/






/// @dev `LiquidPledgingBase` is the base level contract used to carry out
///  liquidPledging's most basic functions, mostly handling and searching the
///  data structures
contract LiquidPledgingBase is EscapableApp, LiquidPledgingStorage, PledgeAdmins, Pledges {

    // Event Declarations
    event Transfer(uint indexed from, uint indexed to, uint amount);
    event CancelProject(uint indexed idProject);

/////////////
// Modifiers
/////////////

    /// @dev The `vault`is the only addresses that can call a function with this
    ///  modifier
    modifier onlyVault() {
        require(msg.sender == address(vault));
        _;
    }

///////////////
// Constructor
///////////////

    function initialize(address _escapeHatchDestination) onlyInit public {
        require(false); // overload the EscapableApp
        _escapeHatchDestination;
    }

    /// @param _vault The vault where the ETH backing the pledges is stored
    /// @param _escapeHatchDestination The address of a safe location (usu a
    ///  Multisig) to send the ether held in this contract; if a neutral address
    ///  is required, the WHG Multisig is an option:
    ///  0x8Ff920020c8AD673661c8117f2855C384758C572 
    function initialize(address _vault, address _escapeHatchDestination) onlyInit public {
        super.initialize(_escapeHatchDestination);
        require(_vault != 0x0);

        vault = ILPVault(_vault);

        admins.length = 1; // we reserve the 0 admin
        pledges.length = 1; // we reserve the 0 pledge
    }


/////////////////////////////
// Public constant functions
/////////////////////////////

    /// @notice Getter to find Delegate w/ the Pledge ID & the Delegate index
    /// @param idPledge The id number representing the pledge being queried
    /// @param idxDelegate The index number for the delegate in this Pledge 
    function getPledgeDelegate(uint64 idPledge, uint64 idxDelegate) public view returns(
        uint64 idDelegate,
        address addr,
        string name
    ) {
        Pledge storage p = _findPledge(idPledge);
        idDelegate = p.delegationChain[idxDelegate - 1];
        PledgeAdmin storage delegate = _findAdmin(idDelegate);
        addr = delegate.addr;
        name = delegate.name;
    }

    /// @notice Only affects pledges with the Pledged PledgeState for 2 things:
    ///   #1: Checks if the pledge should be committed. This means that
    ///       if the pledge has an intendedProject and it is past the
    ///       commitTime, it changes the owner to be the proposed project
    ///       (The UI will have to read the commit time and manually do what
    ///       this function does to the pledge for the end user
    ///       at the expiration of the commitTime)
    ///
    ///   #2: Checks to make sure that if there has been a cancellation in the
    ///       chain of projects, the pledge's owner has been changed
    ///       appropriately.
    ///
    /// This function can be called by anybody at anytime on any pledge.
    ///  In general it can be called to force the calls of the affected 
    ///  plugins, which also need to be predicted by the UI
    /// @param idPledge This is the id of the pledge that will be normalized
    /// @return The normalized Pledge!
    function normalizePledge(uint64 idPledge) public returns(uint64) {
        Pledge storage p = _findPledge(idPledge);

        // Check to make sure this pledge hasn't already been used 
        // or is in the process of being used
        if (p.pledgeState != PledgeState.Pledged) {
            return idPledge;
        }

        // First send to a project if it's proposed and committed
        if ((p.intendedProject > 0) && ( _getTime() > p.commitTime)) {
            uint64 oldPledge = _findOrCreatePledge(
                p.owner,
                p.delegationChain,
                0,
                0,
                p.oldPledge,
                p.token,
                PledgeState.Pledged
            );
            uint64 toPledge = _findOrCreatePledge(
                p.intendedProject,
                new uint64[](0),
                0,
                0,
                oldPledge,
                p.token,
                PledgeState.Pledged
            );
            _doTransfer(idPledge, toPledge, p.amount);
            idPledge = toPledge;
            p = _findPledge(idPledge);
        }

        toPledge = _getOldestPledgeNotCanceled(idPledge);
        if (toPledge != idPledge) {
            _doTransfer(idPledge, toPledge, p.amount);
        }

        return toPledge;
    }

////////////////////
// Internal methods
////////////////////

    /// @notice A check to see if the msg.sender is the owner or the
    ///  plugin contract for a specific Admin
    /// @param idAdmin The id of the admin being checked
    function checkAdminOwner(uint64 idAdmin) internal constant {
        PledgeAdmin storage a = _findAdmin(idAdmin);
        require(msg.sender == address(a.plugin) || msg.sender == a.addr);
    }

    function _transfer( 
        uint64 idSender,
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal
    {
        require(idReceiver > 0); // prevent burning value
        idPledge = normalizePledge(idPledge);

        Pledge storage p = _findPledge(idPledge);
        PledgeAdmin storage receiver = _findAdmin(idReceiver);

        require(p.pledgeState == PledgeState.Pledged);

        // If the sender is the owner of the Pledge
        if (p.owner == idSender) {

            if (receiver.adminType == PledgeAdminType.Giver) {
                _transferOwnershipToGiver(idPledge, amount, idReceiver);
            } else if (receiver.adminType == PledgeAdminType.Project) {
                _transferOwnershipToProject(idPledge, amount, idReceiver);
            } else if (receiver.adminType == PledgeAdminType.Delegate) {

                uint recieverDIdx = _getDelegateIdx(p, idReceiver);
                if (p.intendedProject > 0 && recieverDIdx != NOTFOUND) {
                    // if there is an intendedProject and the receiver is in the delegationChain,
                    // then we want to preserve the delegationChain as this is a veto of the
                    // intendedProject by the owner

                    if (recieverDIdx == p.delegationChain.length - 1) {
                        uint64 toPledge = _findOrCreatePledge(
                            p.owner,
                            p.delegationChain,
                            0,
                            0,
                            p.oldPledge,
                            p.token,
                            PledgeState.Pledged);
                        _doTransfer(idPledge, toPledge, amount);
                    } else {
                        _undelegate(idPledge, amount, p.delegationChain.length - receiverDIdx - 1);
                    }
                } else {
                    // owner is not vetoing an intendedProject and is transferring the pledge to a delegate,
                    // so we want to reset the delegationChain
                    idPledge = _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length
                    );
                    _appendDelegate(idPledge, amount, idReceiver);
                }

            } else {
                // This should never be reached as the receiver.adminType
                // should always be either a Giver, Project, or Delegate
                assert(false);
            }
            return;
        }

        // If the sender is a Delegate
        uint senderDIdx = _getDelegateIdx(p, idSender);
        if (senderDIdx != NOTFOUND) {

            // And the receiver is another Giver
            if (receiver.adminType == PledgeAdminType.Giver) {
                // Only transfer to the Giver who owns the pledge
                assert(p.owner == idReceiver);
                _undelegate(idPledge, amount, p.delegationChain.length);
                return;
            }

            // And the receiver is another Delegate
            if (receiver.adminType == PledgeAdminType.Delegate) {
                uint receiverDIdx = _getDelegateIdx(p, idReceiver);

                // And not in the delegationChain
                if (receiverDIdx == NOTFOUND) {
                    idPledge = _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length - senderDIdx - 1
                    );
                    _appendDelegate(idPledge, amount, idReceiver);

                // And part of the delegationChain and is after the sender, then
                //  all of the other delegates after the sender are removed and
                //  the receiver is appended at the end of the delegationChain
                } else if (receiverDIdx > senderDIdx) {
                    idPledge = _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length - senderDIdx - 1
                    );
                    _appendDelegate(idPledge, amount, idReceiver);

                // And is already part of the delegate chain but is before the
                //  sender, then the sender and all of the other delegates after
                //  the RECEIVER are removed from the delegationChain
                } else if (receiverDIdx <= senderDIdx) {//TODO Check for Game Theory issues (from Arthur) this allows the sender to sort of go komakosi and remove himself and the delegates between himself and the receiver... should this authority be allowed?
                    _undelegate(
                        idPledge,
                        amount,
                        p.delegationChain.length - receiverDIdx - 1
                    );
                }
                return;
            }

            // And the receiver is a Project, all the delegates after the sender
            //  are removed and the amount is pre-committed to the project
            if (receiver.adminType == PledgeAdminType.Project) {
                idPledge = _undelegate(
                    idPledge,
                    amount,
                    p.delegationChain.length - senderDIdx - 1
                );
                _proposeAssignProject(idPledge, amount, idReceiver);
                return;
            }
        }
        assert(false);  // When the sender is not an owner or a delegate
    }

    /// @notice `transferOwnershipToProject` allows for the transfer of
    ///  ownership to the project, but it can also be called by a project
    ///  to un-delegate everyone by setting one's own id for the idReceiver
    /// @param idPledge the id of the pledge to be transfered.
    /// @param amount Quantity of value that's being transfered
    /// @param idReceiver The new owner of the project (or self to un-delegate)
    function _transferOwnershipToProject(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        // Ensure that the pledge is not already at max pledge depth
        // and the project has not been canceled
        require(_getPledgeLevel(p) < MAX_INTERPROJECT_LEVEL);
        require(!isProjectCanceled(idReceiver));

        uint64 oldPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        uint64 toPledge = _findOrCreatePledge(
            idReceiver,                     // Set the new owner
            new uint64[](0),                // clear the delegation chain
            0,
            0,
            oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }   


    /// @notice `transferOwnershipToGiver` allows for the transfer of
    ///  value back to the Giver, value is placed in a pledged state
    ///  without being attached to a project, delegation chain, or time line.
    /// @param idPledge the id of the pledge to be transferred.
    /// @param amount Quantity of value that's being transferred
    /// @param idReceiver The new owner of the pledge
    function _transferOwnershipToGiver(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        uint64 toPledge = _findOrCreatePledge(
            idReceiver,
            new uint64[](0),
            0,
            0,
            0,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `appendDelegate` allows for a delegate to be added onto the
    ///  end of the delegate chain for a given Pledge.
    /// @param idPledge the id of the pledge thats delegate chain will be modified.
    /// @param amount Quantity of value that's being chained.
    /// @param idReceiver The delegate to be added at the end of the chain
    function _appendDelegate(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        require(p.delegationChain.length < MAX_DELEGATES);
        uint64[] memory newDelegationChain = new uint64[](
            p.delegationChain.length + 1
        );
        for (uint i = 0; i < p.delegationChain.length; i++) {
            newDelegationChain[i] = p.delegationChain[i];
        }

        // Make the last item in the array the idReceiver
        newDelegationChain[p.delegationChain.length] = idReceiver;

        uint64 toPledge = _findOrCreatePledge(
            p.owner,
            newDelegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `appendDelegate` allows for a delegate to be added onto the
    ///  end of the delegate chain for a given Pledge.
    /// @param idPledge the id of the pledge thats delegate chain will be modified.
    /// @param amount Quantity of value that's shifted from delegates.
    /// @param q Number (or depth) of delegates to remove
    /// @return toPledge The id for the pledge being adjusted or created
    function _undelegate(
        uint64 idPledge,
        uint amount,
        uint q
    ) internal returns (uint64 toPledge)
    {
        Pledge storage p = _findPledge(idPledge);
        uint64[] memory newDelegationChain = new uint64[](
            p.delegationChain.length - q
        );

        for (uint i = 0; i < p.delegationChain.length - q; i++) {
            newDelegationChain[i] = p.delegationChain[i];
        }
        toPledge = _findOrCreatePledge(
            p.owner,
            newDelegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `proposeAssignProject` proposes the assignment of a pledge
    ///  to a specific project.
    /// @dev This function should potentially be named more specifically.
    /// @param idPledge the id of the pledge that will be assigned.
    /// @param amount Quantity of value this pledge leader would be assigned.
    /// @param idReceiver The project this pledge will potentially 
    ///  be assigned to.
    function _proposeAssignProject(
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) internal 
    {
        Pledge storage p = _findPledge(idPledge);

        require(_getPledgeLevel(p) < MAX_INTERPROJECT_LEVEL);
        require(!isProjectCanceled(idReceiver));

        uint64 toPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            idReceiver,
            uint64(_getTime() + _maxCommitTime(p)),
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );
        _doTransfer(idPledge, toPledge, amount);
    }

    /// @notice `doTransfer` is designed to allow for pledge amounts to be 
    ///  shifted around internally.
    /// @param from This is the id of the pledge from which value will be transferred.
    /// @param to This is the id of the pledge that value will be transferred to.
    /// @param _amount The amount of value that will be transferred.
    function _doTransfer(uint64 from, uint64 to, uint _amount) internal {
        uint amount = _callPlugins(true, from, to, _amount);
        if (from == to) {
            return;
        }
        if (amount == 0) {
            return;
        }

        Pledge storage pFrom = _findPledge(from);
        Pledge storage pTo = _findPledge(to);

        require(pFrom.amount >= amount);
        pFrom.amount -= amount;
        pTo.amount += amount;

        Transfer(from, to, amount);
        _callPlugins(false, from, to, amount);
    }

    /// @notice A getter to find the longest commitTime out of the owner and all
    ///  the delegates for a specified pledge
    /// @param p The Pledge being queried
    /// @return The maximum commitTime out of the owner and all the delegates
    function _maxCommitTime(Pledge p) internal view returns(uint64 commitTime) {
        PledgeAdmin storage a = _findAdmin(p.owner);
        commitTime = a.commitTime; // start with the owner's commitTime

        for (uint i = 0; i < p.delegationChain.length; i++) {
            a = _findAdmin(p.delegationChain[i]);

            // If a delegate's commitTime is longer, make it the new commitTime
            if (a.commitTime > commitTime) {
                commitTime = a.commitTime;
            }
        }
    }

    /// @notice A getter to find the oldest pledge that hasn't been canceled
    /// @param idPledge The starting place to lookup the pledges
    /// @return The oldest idPledge that hasn't been canceled (DUH!)
    function _getOldestPledgeNotCanceled(
        uint64 idPledge
    ) internal view returns(uint64)
    {
        if (idPledge == 0) {
            return 0;
        }

        Pledge storage p = _findPledge(idPledge);
        PledgeAdmin storage admin = _findAdmin(p.owner);
        
        if (admin.adminType == PledgeAdminType.Giver) {
            return idPledge;
        }

        assert(admin.adminType == PledgeAdminType.Project);
        if (!isProjectCanceled(p.owner)) {
            return idPledge;
        }

        return _getOldestPledgeNotCanceled(p.oldPledge);
    }

    /// @notice `callPlugin` is used to trigger the general functions in the
    ///  plugin for any actions needed before and after a transfer happens.
    ///  Specifically what this does in relation to the plugin is something
    ///  that largely depends on the functions of that plugin. This function
    ///  is generally called in pairs, once before, and once after a transfer.
    /// @param before This toggle determines whether the plugin call is occurring
    ///  before or after a transfer.
    /// @param adminId This should be the Id of the *trusted* individual
    ///  who has control over this plugin.
    /// @param fromPledge This is the Id from which value is being transfered.
    /// @param toPledge This is the Id that value is being transfered to.
    /// @param context The situation that is triggering the plugin. See plugin
    ///  for a full description of contexts.
    /// @param amount The amount of value that is being transfered.
    function _callPlugin(
        bool before,
        uint64 adminId,
        uint64 fromPledge,
        uint64 toPledge,
        uint64 context,
        address token,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        uint newAmount;
        allowedAmount = amount;
        PledgeAdmin storage admin = _findAdmin(adminId);

        // Checks admin has a plugin assigned and a non-zero amount is requested
        if (address(admin.plugin) != 0 && allowedAmount > 0) {
            // There are two separate functions called in the plugin.
            // One is called before the transfer and one after
            if (before) {
                newAmount = admin.plugin.beforeTransfer(
                    adminId,
                    fromPledge,
                    toPledge,
                    context,
                    token,
                    amount
                );
                require(newAmount <= allowedAmount);
                allowedAmount = newAmount;
            } else {
                admin.plugin.afterTransfer(
                    adminId,
                    fromPledge,
                    toPledge,
                    context,
                    token,
                    amount
                );
            }
        }
    }

    /// @notice `callPluginsPledge` is used to apply plugin calls to
    ///  the delegate chain and the intended project if there is one.
    ///  It does so in either a transferring or receiving context based
    ///  on the `p` and  `fromPledge` parameters.
    /// @param before This toggle determines whether the plugin call is occuring
    ///  before or after a transfer.
    /// @param idPledge This is the id of the pledge on which this plugin
    ///  is being called.
    /// @param fromPledge This is the Id from which value is being transfered.
    /// @param toPledge This is the Id that value is being transfered to.
    /// @param amount The amount of value that is being transfered.
    function _callPluginsPledge(
        bool before,
        uint64 idPledge,
        uint64 fromPledge,
        uint64 toPledge,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        // Determine if callPlugin is being applied in a receiving
        // or transferring context
        uint64 offset = idPledge == fromPledge ? 0 : 256;
        allowedAmount = amount;
        Pledge storage p = _findPledge(idPledge);

        // Always call the plugin on the owner
        allowedAmount = _callPlugin(
            before,
            p.owner,
            fromPledge,
            toPledge,
            offset,
            p.token,
            allowedAmount
        );

        // Apply call plugin to all delegates
        for (uint64 i = 0; i < p.delegationChain.length; i++) {
            allowedAmount = _callPlugin(
                before,
                p.delegationChain[i],
                fromPledge,
                toPledge,
                offset + i + 1,
                p.token,
                allowedAmount
            );
        }

        // If there is an intended project also call the plugin in
        // either a transferring or receiving context based on offset
        // on the intended project
        if (p.intendedProject > 0) {
            allowedAmount = _callPlugin(
                before,
                p.intendedProject,
                fromPledge,
                toPledge,
                offset + 255,
                p.token,
                allowedAmount
            );
        }
    }

    /// @notice `callPlugins` calls `callPluginsPledge` once for the transfer
    ///  context and once for the receiving context. The aggregated 
    ///  allowed amount is then returned.
    /// @param before This toggle determines whether the plugin call is occurring
    ///  before or after a transfer.
    /// @param fromPledge This is the Id from which value is being transferred.
    /// @param toPledge This is the Id that value is being transferred to.
    /// @param amount The amount of value that is being transferred.
    function _callPlugins(
        bool before,
        uint64 fromPledge,
        uint64 toPledge,
        uint amount
    ) internal returns (uint allowedAmount) 
    {
        allowedAmount = amount;

        // Call the plugins in the transfer context
        allowedAmount = _callPluginsPledge(
            before,
            fromPledge,
            fromPledge,
            toPledge,
            allowedAmount
        );

        // Call the plugins in the receive context
        allowedAmount = _callPluginsPledge(
            before,
            toPledge,
            fromPledge,
            toPledge,
            allowedAmount
        );
    }

/////////////
// Test functions
/////////////

    /// @notice Basic helper function to return the current time
    function _getTime() internal view returns (uint) {
        return now;
    }
}


///File: ./contracts/LiquidPledging.sol

pragma solidity ^0.4.18;

/*
    Copyright 2017, Jordi Baylina, RJ Ewing
    Contributors: Adrià Massanet <adria@codecontext.io>, Griff Green,
    Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/



/// @dev `LiquidPledging` allows for liquid pledging through the use of
///  internal id structures and delegate chaining. All basic operations for
///  handling liquid pledging are supplied as well as plugin features
///  to allow for expanded functionality.
contract LiquidPledging is LiquidPledgingBase {


    function addGiverAndDonate(uint64 idReceiver, address token, uint amount)
        public
    {
        addGiverAndDonate(idReceiver, msg.sender, token, amount);
    }

    function addGiverAndDonate(uint64 idReceiver, address donorAddress, address token, uint amount)
        public
    {
        require(donorAddress != 0);
        // default to a 3 day (259200 seconds) commitTime
        uint64 idGiver = addGiver(donorAddress, "", "", 259200, ILiquidPledgingPlugin(0));
        donate(idGiver, idReceiver, token, amount);
    }

    /// @notice This is how value enters the system and how pledges are created;
    ///  the ether is sent to the vault, an pledge for the Giver is created (or
    ///  found), the amount of ETH donated in wei is added to the `amount` in
    ///  the Giver's Pledge, and an LP transfer is done to the idReceiver for
    ///  the full amount
    /// @param idGiver The id of the Giver donating; if 0, a new id is created
    /// @param idReceiver The Admin receiving the donation; can be any Admin:
    ///  the Giver themselves, another Giver, a Delegate or a Project
    function donate(uint64 idGiver, uint64 idReceiver, address token, uint amount)
        public
    {
        require(idGiver > 0); // prevent burning donations. idReceiver is checked in _transfer
        require(amount > 0);
        require(token != 0x0);

        PledgeAdmin storage sender = _findAdmin(idGiver);
        require(sender.adminType == PledgeAdminType.Giver);

        require(ERC20(token).transferFrom(msg.sender, address(vault), amount)); // transfer the token to the `vault`

        uint64 idPledge = _findOrCreatePledge(
            idGiver,
            new uint64[](0), // Creates empty array for delegationChain
            0,
            0,
            0,
            token,
            PledgeState.Pledged
        );

        Pledge storage pTo = _findPledge(idPledge);
        pTo.amount += amount;

        Transfer(0, idPledge, amount);

        _transfer(idGiver, idPledge, amount, idReceiver);
    }

    /// @notice Transfers amounts between pledges for internal accounting
    /// @param idSender Id of the Admin that is transferring the amount from
    ///  Pledge to Pledge; this admin must have permissions to move the value
    /// @param idPledge Id of the pledge that's moving the value
    /// @param amount Quantity of ETH (in wei) that this pledge is transferring 
    ///  the authority to withdraw from the vault
    /// @param idReceiver Destination of the `amount`, can be a Giver/Project sending
    ///  to a Giver, a Delegate or a Project; a Delegate sending to another
    ///  Delegate, or a Delegate pre-commiting it to a Project 
    function transfer( 
        uint64 idSender,
        uint64 idPledge,
        uint amount,
        uint64 idReceiver
    ) public
    {
        checkAdminOwner(idSender);
        _transfer(idSender, idPledge, amount, idReceiver);
    }

    /// @notice Authorizes a payment be made from the `vault` can be used by the
    ///  Giver to veto a pre-committed donation from a Delegate to an
    ///  intendedProject
    /// @param idPledge Id of the pledge that is to be redeemed into ether
    /// @param amount Quantity of ether (in wei) to be authorized
    function withdraw(uint64 idPledge, uint amount) public {
        idPledge = normalizePledge(idPledge); // Updates pledge info 

        Pledge storage p = _findPledge(idPledge);
        require(p.pledgeState == PledgeState.Pledged);
        checkAdminOwner(p.owner);

        uint64 idNewPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Paying
        );

        _doTransfer(idPledge, idNewPledge, amount);

        PledgeAdmin storage owner = _findAdmin(p.owner);
        vault.authorizePayment(bytes32(idNewPledge), owner.addr, p.token, amount);
    }

    /// @notice `onlyVault` Confirms a withdraw request changing the PledgeState
    ///  from Paying to Paid
    /// @param idPledge Id of the pledge that is to be withdrawn
    /// @param amount Quantity of ether (in wei) to be withdrawn
    function confirmPayment(uint64 idPledge, uint amount) public onlyVault {
        Pledge storage p = _findPledge(idPledge);

        require(p.pledgeState == PledgeState.Paying);

        uint64 idNewPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Paid
        );

        _doTransfer(idPledge, idNewPledge, amount);
    }

    /// @notice `onlyVault` Cancels a withdraw request, changing the PledgeState
    ///  from Paying back to Pledged
    /// @param idPledge Id of the pledge that's withdraw is to be canceled
    /// @param amount Quantity of ether (in wei) to be canceled
    function cancelPayment(uint64 idPledge, uint amount) public onlyVault {
        Pledge storage p = _findPledge(idPledge);

        require(p.pledgeState == PledgeState.Paying);

        // When a payment is canceled, never is assigned to a project.
        uint64 idOldPledge = _findOrCreatePledge(
            p.owner,
            p.delegationChain,
            0,
            0,
            p.oldPledge,
            p.token,
            PledgeState.Pledged
        );

        idOldPledge = normalizePledge(idOldPledge);

        _doTransfer(idPledge, idOldPledge, amount);
    }

    /// @notice Changes the `project.canceled` flag to `true`; cannot be undone
    /// @param idProject Id of the project that is to be canceled
    function cancelProject(uint64 idProject) public {
        PledgeAdmin storage project = _findAdmin(idProject);
        checkAdminOwner(idProject);
        project.canceled = true;

        CancelProject(idProject);
    }

    /// @notice Transfers `amount` in `idPledge` back to the `oldPledge` that
    ///  that sent it there in the first place, a Ctrl-z 
    /// @param idPledge Id of the pledge that is to be canceled
    /// @param amount Quantity of ether (in wei) to be transfered to the 
    ///  `oldPledge`
    function cancelPledge(uint64 idPledge, uint amount) public {
        idPledge = normalizePledge(idPledge);

        Pledge storage p = _findPledge(idPledge);
        require(p.oldPledge != 0);
        checkAdminOwner(p.owner);

        uint64 oldPledge = _getOldestPledgeNotCanceled(p.oldPledge);
        _doTransfer(idPledge, oldPledge, amount);
    }


////////
// Multi pledge methods
////////

    // @dev This set of functions makes moving a lot of pledges around much more
    // efficient (saves gas) than calling these functions in series
    
    
    /// @dev Bitmask used for dividing pledge amounts in Multi pledge methods
    uint constant D64 = 0x10000000000000000;

    /// @notice Transfers multiple amounts within multiple Pledges in an
    ///  efficient single call 
    /// @param idSender Id of the Admin that is transferring the amounts from
    ///  all the Pledges; this admin must have permissions to move the value
    /// @param pledgesAmounts An array of Pledge amounts and the idPledges with 
    ///  which the amounts are associated; these are extrapolated using the D64
    ///  bitmask
    /// @param idReceiver Destination of the `pledesAmounts`, can be a Giver or 
    ///  Project sending to a Giver, a Delegate or a Project; a Delegate sending
    ///  to another Delegate, or a Delegate pre-commiting it to a Project 
    function mTransfer(
        uint64 idSender,
        uint[] pledgesAmounts,
        uint64 idReceiver
    ) public 
    {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64( pledgesAmounts[i] & (D64-1) );
            uint amount = pledgesAmounts[i] / D64;

            transfer(idSender, idPledge, amount, idReceiver);
        }
    }

    /// @notice Authorizes multiple amounts within multiple Pledges to be
    ///  withdrawn from the `vault` in an efficient single call 
    /// @param pledgesAmounts An array of Pledge amounts and the idPledges with 
    ///  which the amounts are associated; these are extrapolated using the D64
    ///  bitmask
    function mWithdraw(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64( pledgesAmounts[i] & (D64-1) );
            uint amount = pledgesAmounts[i] / D64;

            withdraw(idPledge, amount);
        }
    }

    /// @notice `mConfirmPayment` allows for multiple pledges to be confirmed
    ///  efficiently
    /// @param pledgesAmounts An array of pledge amounts and IDs which are extrapolated
    ///  using the D64 bitmask
    function mConfirmPayment(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64( pledgesAmounts[i] & (D64-1) );
            uint amount = pledgesAmounts[i] / D64;

            confirmPayment(idPledge, amount);
        }
    }

    /// @notice `mCancelPayment` allows for multiple pledges to be canceled
    ///  efficiently
    /// @param pledgesAmounts An array of pledge amounts and IDs which are extrapolated
    ///  using the D64 bitmask
    function mCancelPayment(uint[] pledgesAmounts) public {
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint64 idPledge = uint64( pledgesAmounts[i] & (D64-1) );
            uint amount = pledgesAmounts[i] / D64;

            cancelPayment(idPledge, amount);
        }
    }

    /// @notice `mNormalizePledge` allows for multiple pledges to be
    ///  normalized efficiently
    /// @param pledges An array of pledge IDs
    function mNormalizePledge(uint64[] pledges) public {
        for (uint i = 0; i < pledges.length; i++ ) {
            normalizePledge( pledges[i] );
        }
    }
}


///File: @aragon/os/contracts/kernel/KernelStorage.sol

pragma solidity 0.4.18;


contract KernelConstants {
    bytes32 constant public CORE_NAMESPACE = keccak256("core");
    bytes32 constant public APP_BASES_NAMESPACE = keccak256("base");
    bytes32 constant public APP_ADDR_NAMESPACE = keccak256("app");

    bytes32 constant public KERNEL_APP_ID = keccak256("kernel.aragonpm.eth");
    bytes32 constant public KERNEL_APP = keccak256(CORE_NAMESPACE, KERNEL_APP_ID);

    bytes32 constant public ACL_APP_ID = keccak256("acl.aragonpm.eth");
    bytes32 constant public ACL_APP = keccak256(APP_ADDR_NAMESPACE, ACL_APP_ID);
}


contract KernelStorage is KernelConstants {
    mapping (bytes32 => address) public apps;
}


///File: @aragon/os/contracts/apps/IAppProxy.sol

pragma solidity 0.4.18;

interface IAppProxy {
    function isUpgradeable() public pure returns (bool);
    function getCode() public view returns (address);
}


///File: @aragon/os/contracts/common/DelegateProxy.sol

pragma solidity 0.4.18;


contract DelegateProxy {
    /**
    * @dev Performs a delegatecall and returns whatever the delegatecall returned (entire context execution will return!)
    * @param _dst Destination address to perform the delegatecall
    * @param _calldata Calldata for the delegatecall
    */
    function delegatedFwd(address _dst, bytes _calldata) internal {
        require(isContract(_dst));
        assembly {
            let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, 0)
            let size := returndatasize

            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
            // if the call returned error data, forward it
            switch result case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    function isContract(address _target) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_target) }
        return size > 0;
    }
}


///File: @aragon/os/contracts/apps/AppProxyBase.sol

pragma solidity 0.4.18;







contract AppProxyBase is IAppProxy, AppStorage, DelegateProxy, KernelConstants {
    /**
    * @dev Initialize AppProxy
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyBase(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public {
        kernel = _kernel;
        appId = _appId;

        // Implicit check that kernel is actually a Kernel
        // The EVM doesn't actually provide a way for us to make sure, but we can force a revert to
        // occur if the kernel is set to 0x0 or a non-code address when we try to call a method on
        // it.
        address appCode = getAppBase(appId);

        // If initialize payload is provided, it will be executed
        if (_initializePayload.length > 0) {
            require(isContract(appCode));
            // Cannot make delegatecall as a delegateproxy.delegatedFwd as it
            // returns ending execution context and halts contract deployment
            require(appCode.delegatecall(_initializePayload));
        }
    }

    function getAppBase(bytes32 _appId) internal view returns (address) {
        return kernel.getApp(keccak256(APP_BASES_NAMESPACE, _appId));
    }

    function () payable public {
        address target = getCode();
        require(target != 0); // if app code hasn't been set yet, don't call
        delegatedFwd(target, msg.data);
    }
}

///File: @aragon/os/contracts/apps/AppProxyUpgradeable.sol

pragma solidity 0.4.18;




contract AppProxyUpgradeable is AppProxyBase {
    address public pinnedCode;

    /**
    * @dev Initialize AppProxyUpgradeable (makes it an upgradeable Aragon app)
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyUpgradeable(IKernel _kernel, bytes32 _appId, bytes _initializePayload)
             AppProxyBase(_kernel, _appId, _initializePayload) public
    {

    }

    function getCode() public view returns (address) {
        return getAppBase(appId);
    }

    function isUpgradeable() public pure returns (bool) {
        return true;
    }
}


///File: @aragon/os/contracts/apps/AppProxyPinned.sol

pragma solidity 0.4.18;




contract AppProxyPinned is AppProxyBase {
    /**
    * @dev Initialize AppProxyPinned (makes it an un-upgradeable Aragon app)
    * @param _kernel Reference to organization kernel for the app
    * @param _appId Identifier for app
    * @param _initializePayload Payload for call to be made after setup to initialize
    */
    function AppProxyPinned(IKernel _kernel, bytes32 _appId, bytes _initializePayload)
             AppProxyBase(_kernel, _appId, _initializePayload) public
    {
        pinnedCode = getAppBase(appId);
        require(pinnedCode != address(0));
    }

    function getCode() public view returns (address) {
        return pinnedCode;
    }

    function isUpgradeable() public pure returns (bool) {
        return false;
    }

    function () payable public {
        delegatedFwd(getCode(), msg.data);
    }
}

///File: @aragon/os/contracts/factory/AppProxyFactory.sol

pragma solidity 0.4.18;





contract AppProxyFactory {
    event NewAppProxy(address proxy);

    function newAppProxy(IKernel _kernel, bytes32 _appId) public returns (AppProxyUpgradeable) {
        return newAppProxy(_kernel, _appId, new bytes(0));
    }

    function newAppProxy(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public returns (AppProxyUpgradeable) {
        AppProxyUpgradeable proxy = new AppProxyUpgradeable(_kernel, _appId, _initializePayload);
        NewAppProxy(address(proxy));
        return proxy;
    }

    function newAppProxyPinned(IKernel _kernel, bytes32 _appId) public returns (AppProxyPinned) {
        return newAppProxyPinned(_kernel, _appId, new bytes(0));
    }

    function newAppProxyPinned(IKernel _kernel, bytes32 _appId, bytes _initializePayload) public returns (AppProxyPinned) {
        AppProxyPinned proxy = new AppProxyPinned(_kernel, _appId, _initializePayload);
        NewAppProxy(address(proxy));
        return proxy;
    }
}


///File: @aragon/os/contracts/kernel/Kernel.sol

pragma solidity 0.4.18;









contract Kernel is IKernel, KernelStorage, Initializable, AppProxyFactory, ACLSyntaxSugar {
    bytes32 constant public APP_MANAGER_ROLE = bytes32(1);

    /**
    * @dev Initialize can only be called once. It saves the block number in which it was initialized.
    * @notice Initializes a kernel instance along with its ACL and sets `_permissionsCreator` as the entity that can create other permissions
    * @param _baseAcl Address of base ACL app
    * @param _permissionsCreator Entity that will be given permission over createPermission
    */
    function initialize(address _baseAcl, address _permissionsCreator) onlyInit public {
        initialized();

        IACL acl = IACL(newAppProxy(this, ACL_APP_ID));

        _setApp(APP_BASES_NAMESPACE, ACL_APP_ID, _baseAcl);
        _setApp(APP_ADDR_NAMESPACE, ACL_APP_ID, acl);

        acl.initialize(_permissionsCreator);
    }

    /**
    * @dev Create a new instance of an app linked to this kernel and set its base
    *      implementation if it was not already set
    * @param _name Name of the app
    * @param _appBase Address of the app's base implementation
    * @return AppProxy instance
    */
    function newAppInstance(bytes32 _name, address _appBase) auth(APP_MANAGER_ROLE, arr(APP_BASES_NAMESPACE, _name)) public returns (IAppProxy appProxy) {
        _setAppIfNew(APP_BASES_NAMESPACE, _name, _appBase);
        appProxy = newAppProxy(this, _name);
    }

    /**
    * @dev Create a new pinned instance of an app linked to this kernel and set
    *      its base implementation if it was not already set
    * @param _name Name of the app
    * @param _appBase Address of the app's base implementation
    * @return AppProxy instance
    */
    function newPinnedAppInstance(bytes32 _name, address _appBase) auth(APP_MANAGER_ROLE, arr(APP_BASES_NAMESPACE, _name)) public returns (IAppProxy appProxy) {
        _setAppIfNew(APP_BASES_NAMESPACE, _name, _appBase);
        appProxy = newAppProxyPinned(this, _name);
    }

    /**
    * @dev Set the resolving address of an app instance or base implementation
    * @param _namespace App namespace to use
    * @param _name Name of the app
    * @param _app Address of the app
    * @return ID of app
    */
    function setApp(bytes32 _namespace, bytes32 _name, address _app) auth(APP_MANAGER_ROLE, arr(_namespace, _name)) kernelIntegrity public returns (bytes32 id) {
        return _setApp(_namespace, _name, _app);
    }

    /**
    * @dev Get the address of an app instance or base implementation
    * @param _id App identifier
    * @return Address of the app
    */
    function getApp(bytes32 _id) public view returns (address) {
        return apps[_id];
    }

    /**
    * @dev Get the installed ACL app
    * @return ACL app
    */
    function acl() public view returns (IACL) {
        return IACL(getApp(ACL_APP));
    }

    /**
    * @dev Function called by apps to check ACL on kernel or to check permission status
    * @param _who Sender of the original call
    * @param _where Address of the app
    * @param _what Identifier for a group of actions in app
    * @param _how Extra data for ACL auth
    * @return boolean indicating whether the ACL allows the role or not
    */
    function hasPermission(address _who, address _where, bytes32 _what, bytes _how) public view returns (bool) {
        return acl().hasPermission(_who, _where, _what, _how);
    }

    function _setApp(bytes32 _namespace, bytes32 _name, address _app) internal returns (bytes32 id) {
        id = keccak256(_namespace, _name);
        apps[id] = _app;
        SetApp(_namespace, _name, id, _app);
    }

    function _setAppIfNew(bytes32 _namespace, bytes32 _name, address _app) internal returns (bytes32 id) {
        id = keccak256(_namespace, _name);

        if (_app != address(0)) {
            address app = getApp(id);
            if (app != address(0)) {
                require(app == _app);
            } else {
                apps[id] = _app;
                SetApp(_namespace, _name, id, _app);
            }
        }
    }

    modifier auth(bytes32 _role, uint256[] memory params) {
        bytes memory how;
        uint256 byteLength = params.length * 32;
        assembly {
            how := params // forced casting
            mstore(how, byteLength)
        }
        // Params is invalid from this point fwd
        require(hasPermission(msg.sender, address(this), _role, how));
        _;
    }

    modifier kernelIntegrity {
        _; // After execution check integrity
        address kernel = getApp(KERNEL_APP);
        uint256 size;
        assembly { size := extcodesize(kernel) }
        require(size > 0);
    }
}


///File: ./contracts/LiquidPledgingMock.sol

pragma solidity ^0.4.11;
/*
    Copyright 2017, Jordi Baylina
    Contributor: Adrià Massanet <adria@codecontext.io>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


// hack so that solcpiler will generate a contracts.Kernel object


/// @dev `LiquidPledgingMock` allows for mocking up
///  a `LiquidPledging` contract with the added ability
///  to manipulate the block time for testing purposes.
contract LiquidPledgingMock is LiquidPledging {

    uint public mock_time;

    /// @dev `LiquidPledgingMock` creates a standard `LiquidPledging`
    ///  instance and sets the mocked time to the current blocktime.
    function initialize(address _vault, address _escapeHatchDestination) onlyInit public {
        super.initialize(_vault, _escapeHatchDestination);
        mock_time = now;
    }

    /// @dev `getTime` is a basic getter function for
    ///  the mock_time parameter
    function _getTime() internal view returns (uint) {
        return mock_time;
    }

    /// @dev `setMockedTime` is a basic setter function for
    ///  the mock_time parameter
    /// @param _t This is the value to which the mocked time
    ///  will be set.
    function setMockedTime(uint _t) public {
        mock_time = _t;
    }
}