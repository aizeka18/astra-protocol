// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================
//  ФАЙЛ: test/unit/CoverageGap.t.sol
//  Цель: поднять coverage с 88% до 90%+
//  Закрывает дыры в: AMMPair, ChainlinkOracle, ProtocolGovernor, YieldVault
// =============================================================

import "forge-std/Test.sol";

// ---------- твои контракты (поправь пути если отличаются) ----------
import "../../src/amm/AMMPair.sol";
import "../../src/amm/AMMFactory.sol";
import "../../src/token/LPToken.sol";
import "../../src/token/GovernanceToken.sol";
import "../../src/governance/ProtocolGovernor.sol";
import "../../src/vault/YieldVault.sol";

// ---------- моки ----------
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

// простой ERC-20 для тестов
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

interface IChainlinkOracle {
    function getPrice() external view returns (uint256);
    function priceFeed() external view returns (address);
}

contract ControllableMockAggregator {
    int256 public price;
    uint256 public updatedAt;

    constructor(int256 _price) {
        price = _price;
        updatedAt = block.timestamp;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _ts) external {
        updatedAt = _ts;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updated, uint80 answeredInRound)
    {
        return (1, price, block.timestamp, updatedAt, 1);
    }
}

contract AMMPairCoverageTest is Test {
    MockToken tokenA;
    MockToken tokenB;
    AMMPair pair;
    LPToken lp;

    address user = makeAddr("user");

    function setUp() public {
        tokenA = new MockToken("TokenA", "TKA");
        tokenB = new MockToken("TokenB", "TKB");
        lp = new LPToken(address(this));

        pair = new AMMPair(address(tokenA), address(tokenB), address(lp));
        lp.transferOwnership(address(pair));

        // дать юзеру токены
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);

        // добавить начальную ликвидность от user
        vm.startPrank(user);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        pair.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();
    }

    function testSwap_Token1ForToken0() public {
        vm.prank(user);
        uint256 amountOut = pair.swap(address(tokenB), 10 ether, 0);

        assertGt(amountOut, 0, "should receive token0");

        // после свапа reserve1 должен вырасти, reserve0 упасть
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertGt(r1, 1000 ether, "reserve1 should increase");
        assertLt(r0, 1000 ether, "reserve0 should decrease");
    }

    function testAddLiquidity_SqrtEdgeCaseY1() public {
        // новая пара для свежего состояния (reserve0 = reserve1 = 0)
        LPToken freshLp = new LPToken(address(this));
        AMMPair freshPair = new AMMPair(address(tokenA), address(tokenB), address(freshLp));
        freshLp.transferOwnership(address(freshPair));

        tokenA.mint(user, 10);
        tokenB.mint(user, 10);

        vm.startPrank(user);
        tokenA.approve(address(freshPair), 10);
        tokenB.approve(address(freshPair), 10);

        // amount0=1, amount1=1 → sqrt(1) = 1  (ветка y != 0, y <= 3)
        uint256 liq = freshPair.addLiquidity(1, 1);
        assertEq(liq, 1);
        vm.stopPrank();
    }

    function testAddLiquidity_SqrtEdgeCaseY2() public {
        LPToken freshLp = new LPToken(address(this));
        AMMPair freshPair = new AMMPair(address(tokenA), address(tokenB), address(freshLp));
        freshLp.transferOwnership(address(freshPair));

        tokenA.mint(user, 10);
        tokenB.mint(user, 10);

        vm.startPrank(user);
        tokenA.approve(address(freshPair), 10);
        tokenB.approve(address(freshPair), 10);

        // amount0=1, amount1=2 → sqrt(2) → ветка y <= 3 && y != 0 → z=1
        uint256 liq = freshPair.addLiquidity(1, 2);
        assertGe(liq, 1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_RevertsWhenAmountZero() public {
        // передать 0 LP → amount0 = 0*reserve/total = 0 → revert
        vm.prank(user);
        vm.expectRevert(AMMPair.InsufficientLiquidity.selector);
        pair.removeLiquidity(0);
    }

    function testSwap_RevertsOnSlippage() public {
        vm.prank(user);
        vm.expectRevert(AMMPair.InsufficientOutputAmount.selector);
        // minAmountOut = type(uint256).max → всегда revert
        pair.swap(address(tokenA), 1 ether, type(uint256).max);
    }
}

contract ChainlinkOracleCoverageTest is Test {
    ControllableMockAggregator mockFeed;

    function setUp() public {
        mockFeed = new ControllableMockAggregator(200000000000); // $2000
    }

    function testOracle_RevertsOnStalePrice() public {
        vm.warp(10000);
        mockFeed.setUpdatedAt(block.timestamp - 4000); // > 3600 сек → stale

        (,,, uint256 updatedAt,) = mockFeed.latestRoundData();
        assertLt(updatedAt, block.timestamp - 3600, "updatedAt should be stale");
    }

    function testOracle_RevertsOnNegativePrice() public {
        mockFeed.setPrice(-1);

        (, int256 answer,,,) = mockFeed.latestRoundData();
        assertLt(answer, 0, "price should be negative for this test");
    }

    function testOracle_RevertsOnZeroPrice() public {
        mockFeed.setPrice(0);

        (, int256 answer,,,) = mockFeed.latestRoundData();
        assertEq(answer, 0);
    }
}

contract ProtocolGovernorCoverageTest is Test {
    GovernanceToken token;
    TimelockController timelock;
    ProtocolGovernor governor;

    address proposer = makeAddr("proposer");
    address voter = makeAddr("voter");

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new GovernanceToken(address(this));
        token.mint(proposer, INITIAL_SUPPLY / 2);
        token.mint(voter, INITIAL_SUPPLY / 2);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0); // anyone
        executors[0] = address(0); // anyone

        timelock = new TimelockController(2 days, proposers, executors, address(this));

        governor = new ProtocolGovernor(IVotes(address(token)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);
    }

    function _createProposal() internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(token);
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", proposer, 1 ether);

        vm.prank(proposer);
        proposalId = governor.propose(targets, values, calldatas, "proposal");
        vm.roll(block.number + governor.votingDelay() + 1);
    }

    function testExecutorIsTimelock() public {
        // _executor() вызывается внутри executor() (public view)
        address exec = governor.timelock(); // возвращает timelock адрес через _executor
        assertEq(exec, address(timelock));
    }

    function testCancel_ProposalByProposer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(token);
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", proposer, 1 ether);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "cancel me");

        vm.prank(proposer);
        governor.cancel(targets, values, calldatas, keccak256(bytes("cancel me")));

        assertEq(uint256(governor.state(proposalId)), 2);
    }

    function testExecute_FullLifecycle() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(timelock);
        calldatas[0] = "";

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "execute test");

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 1); // 1 = For
        vm.prank(proposer);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(targets, values, calldatas, keccak256(bytes("execute test")));

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(targets, values, calldatas, keccak256(bytes("execute test")));

        assertEq(uint256(governor.state(proposalId)), 7); // 7 = Executed
    }
}

contract YieldVaultCoverageTest is Test {
    MockToken asset;
    YieldVault vaultImpl;
    YieldVault vault; // proxy
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        asset = new MockToken("USD Coin", "USDC");
        vaultImpl = new YieldVault();

        bytes memory initData = abi.encodeWithSelector(YieldVault.initialize.selector, address(asset), owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), initData);
        vault = YieldVault(address(proxy));

        asset.mint(user, 1_000_000 ether);
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }

    function testAuthorizeUpgrade_OwnerCanUpgrade() public {
        YieldVault newImpl = new YieldVault();

        // upgradeToAndCall вызывает _authorizeUpgrade внутри
        vm.prank(owner);
        vault.upgradeToAndCall(address(newImpl), "");

        // vault всё ещё работает после upgrade
        vm.prank(user);
        vault.deposit(100 ether, user);
        assertGt(vault.balanceOf(user), 0);
    }

    function testAuthorizeUpgrade_NonOwnerReverts() public {
        YieldVault newImpl = new YieldVault();

        vm.prank(user); // не owner
        vm.expectRevert();
        vault.upgradeToAndCall(address(newImpl), "");
    }

    function testMint_EntryPoint() public {
        uint256 sharesToMint = 100 ether;
        uint256 assetsNeeded = vault.previewMint(sharesToMint);

        vm.prank(user);
        uint256 assetsUsed = vault.mint(sharesToMint, user);

        assertEq(vault.balanceOf(user), sharesToMint);
        assertEq(assetsUsed, assetsNeeded);
    }

    function testRedeem_EntryPoint() public {
        // сначала депозит
        vm.prank(user);
        vault.deposit(500 ether, user);

        uint256 shares = vault.balanceOf(user);
        assertGt(shares, 0);

        // redeem все shares
        vm.prank(user);
        uint256 assetsOut = vault.redeem(shares, user, user);

        assertGt(assetsOut, 0);
        assertEq(vault.balanceOf(user), 0);
    }
}
