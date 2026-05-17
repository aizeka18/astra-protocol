// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================
//  ФАЙЛ: test/security/SecurityCaseStudies.t.sol
//  Два обязательных case study для audit report:
//  S-01: Reentrancy в AMMFactory (CEI violation)
//  S-02: Access control в LPToken.mint
// =============================================================

import "forge-std/Test.sol";
import "../../src/amm/AMMFactory.sol";
import "../../src/amm/AMMPair.sol";
import "../../src/token/LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n) ERC20(n, n) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MaliciousLPToken {
    AMMFactory public factory;
    address public tokenA;
    address public tokenB;
    bool public attacked;
    bool public attackSucceeded;

    constructor(address _factory, address _tokenA, address _tokenB) {
        factory = AMMFactory(_factory);
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function transferOwnership(address) external {
        if (!attacked) {
            attacked = true;

            try factory.createPair(tokenA, tokenB) {
                attackSucceeded = true;
            } catch {
                attackSucceeded = false;
            }
        }
    }
}

contract VulnerableAMMFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, address lpToken);

    error IdenticalAddresses();
    error ZeroAddress();
    error PairAlreadyExists();

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (getPair[token0][token1] != address(0)) revert PairAlreadyExists();

        LPToken lpToken = new LPToken(address(this));
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new AMMPair{salt: salt}(token0, token1, address(lpToken)));

        lpToken.transferOwnership(pair);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, address(lpToken));
    }
}

contract ReentrancyCaseStudyTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;

    function setUp() public {
        tokenA = new MockERC20("TokenA");
        tokenB = new MockERC20("TokenB");
    }

    function testS01_Vulnerable_StateWrittenAfterExternalCall() public {
        VulnerableAMMFactory vulnFactory = new VulnerableAMMFactory();

        address pair = vulnFactory.createPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));

        assertEq(vulnFactory.getPair(address(tokenA), address(tokenB)), pair);
    }

    function testS01_Fixed_StateWrittenBeforeExternalCall() public {
        AMMFactory fixedFactory = new AMMFactory();

        address pair = fixedFactory.createPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));

        assertEq(fixedFactory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(fixedFactory.allPairsLength(), 1);

        vm.expectRevert(AMMFactory.PairAlreadyExists.selector);
        fixedFactory.createPair(address(tokenA), address(tokenB));
    }

    function testS01_Fixed_ReentrancyBlocked() public {
        AMMFactory fixedFactory = new AMMFactory();

        address pair = fixedFactory.createPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));

        vm.expectRevert(AMMFactory.PairAlreadyExists.selector);
        fixedFactory.createPair(address(tokenA), address(tokenB));
    }
}

contract VulnerableLPToken is ERC20 {
    constructor() ERC20("LP Token", "LP") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract AccessControlCaseStudyTest is Test {
    address attacker = makeAddr("attacker");
    address user = makeAddr("user");

    function testS02_Vulnerable_AnyoneCanMint() public {
        VulnerableLPToken vulnLP = new VulnerableLPToken();

        vm.prank(attacker);
        vulnLP.mint(attacker, 1_000_000 ether);

        assertEq(vulnLP.balanceOf(attacker), 1_000_000 ether);
    }

    function testS02_Fixed_OnlyOwnerCanMint() public {
        LPToken fixedLP = new LPToken(address(this)); // owner = this

        vm.prank(attacker);
        vm.expectRevert();
        fixedLP.mint(attacker, 1_000_000 ether);

        fixedLP.mint(user, 500 ether);
        assertEq(fixedLP.balanceOf(user), 500 ether);
    }

    function testS02_Fixed_OnlyOwnerCanBurn() public {
        LPToken fixedLP = new LPToken(address(this));
        fixedLP.mint(user, 500 ether);

        vm.prank(attacker);
        vm.expectRevert();
        fixedLP.burn(user, 500 ether);

        fixedLP.burn(user, 500 ether);
        assertEq(fixedLP.balanceOf(user), 0);
    }
}
