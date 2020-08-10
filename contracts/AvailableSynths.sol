pragma solidity ^0.5.16;

// Inheritance
import "./ContractStorage.sol";
import "./interfaces/IAvailableSynths.sol";

// Internal references
import "./interfaces/ISynth.sol";
import "./interfaces/IERC20.sol";


// https://docs.synthetix.io/contracts/source/contracts/AvailableSynths
contract AvailableSynths is ContractStorage, IAvailableSynths {
    /* ========== CONSTANTS ========== */

    bytes32 private constant sUSD = "sUSD";

    /* ========== STATE ========== */

    ISynth[] public availableSynths;
    mapping(bytes32 => ISynth) public synths;
    mapping(address => bytes32) public synthsByAddress;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _resolver) public ContractStorage(_resolver) {}

    /* ========== INTERNAL ========== */

    function _availableCurrencyKeysWithOptionalSNX(bool withSNX, bool withTotalSupplies)
        internal
        view
        returns (bytes32[] memory currencyKeys, uint[] memory totalSupplies)
    {
        currencyKeys = new bytes32[](availableSynths.length + (withSNX ? 1 : 0));

        for (uint i = 0; i < availableSynths.length; i++) {
            currencyKeys[i] = synthsByAddress[address(availableSynths[i])];
            if (withTotalSupplies) {
                totalSupplies[i] = IERC20(address(availableSynths[i])).totalSupply();
            }
        }

        if (withSNX) {
            currencyKeys[availableSynths.length] = "SNX";
        }
    }

    /* ========== VIEWS ========== */

    function availableCurrencyKeysWithSNX() external view returns (bytes32[] memory currencyKeys) {
        (currencyKeys, ) = _availableCurrencyKeysWithOptionalSNX(true, false);
    }

    function availableCurrencyKeys() external view returns (bytes32[] memory currencyKeys) {
        (currencyKeys, ) = _availableCurrencyKeysWithOptionalSNX(false, false);
    }

    function availableSynthCount() external view returns (uint) {
        return availableSynths.length;
    }

    function availableCurrencyKeysWithSNXAndTotalSupply()
        external
        view
        returns (bytes32[] memory synthsAndSNX, uint[] memory totalSupplies)
    {
        (synthsAndSNX, totalSupplies) = _availableCurrencyKeysWithOptionalSNX(true, true);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function addSynth(bytes32 contractName, ISynth synth) external onlyContract(contractName) {
        bytes32 currencyKey = synth.currencyKey();

        require(synths[currencyKey] == ISynth(0), "Synth already exists");
        require(synthsByAddress[address(synth)] == bytes32(0), "Synth address already exists");

        availableSynths.push(synth);
        synths[currencyKey] = synth;
        synthsByAddress[address(synth)] = currencyKey;

        emit SynthAdded(currencyKey, address(synth));
    }

    function removeSynth(bytes32 contractName, bytes32 currencyKey) external onlyContract(contractName) {
        require(address(synths[currencyKey]) != address(0), "Synth does not exist");
        require(IERC20(address(synths[currencyKey])).totalSupply() == 0, "Synth supply exists");
        require(currencyKey != sUSD, "Cannot remove synth");

        // Save the address we're removing for emitting the event at the end.
        address synthToRemove = address(synths[currencyKey]);

        // Remove the synth from the availableSynths array.
        for (uint i = 0; i < availableSynths.length; i++) {
            if (address(availableSynths[i]) == synthToRemove) {
                delete availableSynths[i];

                // Copy the last synth into the place of the one we just deleted
                // If there's only one synth, this is synths[0] = synths[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                availableSynths[i] = availableSynths[availableSynths.length - 1];

                // Decrease the size of the array by one.
                availableSynths.length--;

                break;
            }
        }

        // And remove it from the synths mapping
        delete synthsByAddress[address(synths[currencyKey])];
        delete synths[currencyKey];

        emit SynthRemoved(currencyKey, synthToRemove);
    }

    /* ========== EVENTS ========== */

    event SynthAdded(bytes32 currencyKey, address synth);
    event SynthRemoved(bytes32 currencyKey, address synth);
}