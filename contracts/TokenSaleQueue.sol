pragma solidity 0.4.19;

contract ERC20Interface {
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}

/* 1. Contract is initiated by storing sender as OWNER and with three arguments:
 * deadline : block.number which is also stored as DEADLINE
 * wallet : address which is also stored as WALLET
 * manager : address which is also stored as MANAGER. */
/* Only MANAGER is eglible to perform core functions like authorizing participants as confirmed investors and withdrawing their money as Token sale funds. */
contract TokenSaleQueue {
    using SafeMath for uint256;

    address public owner;
    address public potentialOwner;

    event NewOwner(address old, address current);
    event NewPotentialOwner(address old, address potential);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setNewOwner(address _new) public onlyOwner {
        require(_new != address(0));

        potentialOwner = _new;
        NewPotentialOwner(owner, _new);
    }

    function confirmOwnership() public {
        require(msg.sender == potentialOwner);

        owner = potentialOwner;
        potentialOwner = address(0);
        NewOwner(owner, potentialOwner);
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getPotentialOwner() public view returns (address) {
        return potentialOwner;
    }

    /* 2. Contract has internal mapping DEPOSITS : Address -> balance: uint256 representing balance of everyone whoever used deposit method */
    /* This is where balances of all participants stored. Additional map whitelistUsers of whether the participant is authorized investor is stored. This map determines if the participant funds can be further processed by the contract manager (see 3., 6.) */

    mapping(address => uint256) public deposits;
    address public wallet;
    address public manager;
    uint256 public deadline; /* blocks */

    mapping (address => bool) whitelistUsers;

    function balanceOf(address who) public view returns (uint256 balance) {
        return deposits[who];
    }

    function isAuthorized(address who) public view returns (bool authorized) {
        return whitelistUsers[who];
    }

    function getWallet() public view returns (address) {
        return wallet;
    }

    function getDeadline() public view returns (uint) {
        return deadline;
    }

    function getManager() public view returns (address) {
        return manager;
    }

    event Deposit(address who, uint256 amount);
    event Withdrawal(address who);
    event Authorized(address who);
    event Process(address who);
    event RetrieveUnclaimedFunds(address who);

    function TokenSaleQueue(address _wallet, address _manager,  uint _deadline) public {
        owner = msg.sender;
        wallet = _wallet;
        manager = _manager;
        deadline = _deadline;
    }

    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

    function setNewManager(address _newManager) public onlyOwner {
        require(_newManager != address(0));

        manager = _newManager;
    }

    function setNewWallet(address _newWallet) public onlyOwner {
        require(_newWallet != address(0));

        wallet = _newWallet;
    }

    /* 3. Contract has method authorize with address argument */
    /* Manager authorizes particular participant - operation that allows to use participant money in Token Sale */
    /* Contract checks if sender is equal to manager */
    function authorize(address who) public onlyManager {
        /* Contract updates corresponding value in whitelistUsers mapping using address as the key and sets value = true */
        whitelistUsers[who] = true;
        Authorized(who);
    }

    /* 4. Contract has payable method deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his funds unless they are processed by the contract owner (6.) */
    function deposit() public payable {
        /* Contract checks that method invocation attaches non-zero value. */
        require(msg.value > 0);

        /* Contract checks that `DEADLINE` is not reached. If it is reached, it returns all funds to `sender` */
        require(block.number <= deadline);

        /* Contract adds value sent to the corresponding mapping stored in DEPOSIT using sender as a key */
        deposits[msg.sender] = deposits[msg.sender].add(msg.value);
        Deposit(msg.sender, msg.value);
    }

    /* 5. Contract has method withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (4.) */
    function withdraw() public {
        /* Contract checks that balance of the sender in DEPOSITS mapping is equal amount */
        require(deposits[msg.sender] > 0);

        uint256 balance = deposits[msg.sender];
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        deposits[msg.sender] = 0;

        /* Contract transfers amount to the sender from it's own balance */
        msg.sender.transfer(balance);
        Withdrawal(msg.sender);
    }

    /* 6. Contract has method process */
    /* Sender does final confirmation that his money will be used in the Token Sale */
    function process() public {
        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(deposits[msg.sender] > 0);
        require(whitelistUsers[msg.sender]);

        uint256 balance = deposits[msg.sender];
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        deposits[msg.sender] = 0;

        /* Contract transfers balance to the WALLET */
        require(wallet != address(0));
        wallet.transfer(balance);

        Process(msg.sender);
    }

    /* 7. Contract has method retrieveUnclaimedFunds with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    /* Contract checks if sender is OWNER */
    function retrieveUnclaimedFunds(address who) public onlyOwner {
        require(who != address(0));
        /* Contract checks if current block.number is later than DEADLINE */
        require(block.number > deadline);

        /* Contract checks if record in DEPOSIT mapping with key equal to address argument has non-zero value */
        require(deposits[msg.sender] > 0);

        uint256 balance = deposits[msg.sender];
        /* Contract sets balance of in DEPOSIT mapping to zero */
        deposits[msg.sender] = 0;

        /* Contract sends funds from it's own balance to owner */
        owner.transfer(balance);

        RetrieveUnclaimedFunds(who);
    }

    /* 8. Contract has method retrieveUnclaimedFunds with address argument */
    /* Owner can kill contract and forward unrecognized funds to _recipient after the DEADLINE + 1 month */
    function destroyAndSend(address _recipient) public onlyOwner {
        /* Contract checks if current block.number is later than DEADLINE + 183000 (~ 1 month)*/
        require(_recipient != address(0));
        require(block.number > deadline + 183000);

        selfdestruct(_recipient);
    }

    /* Contract has internal mapping token DEPOSITS : TokenWallet -> Address -> balance: uint representing token balance of everyone whoever used deposit method */
    /* This is where token balances of all participants stored. Additional map of whether the participant is authorized investor is stored. This map determines if the participant tokens can be further processed by the contract manager (see 11, 12) */
    mapping(address => mapping(address => uint256)) public tokenDeposits;

    /* White list of token wallets */
    mapping (address => bool) public whitelistTokenWallets;

    function addTokensInWhitelist (address tokenWallet) public onlyManager {
        require(tokenWallet != address(0));
        whitelistTokenWallets[tokenWallet] = true;
    }

    function tokenInWhiteList(address tokenWallet) public view returns (bool result) {
        return whitelistTokenWallets[tokenWallet];
    }

    function tokenBalanceOf(address tokenWallet, address who) public view returns (uint256 balance) {
        return tokenDeposits[tokenWallet][who];
    }

    event TokenDeposit(address tokenWallet, address who, uint256 amount);
    event TokenWithdrawal(address tokenWallet, address who);
    event TokenProcess(address tokenWallet, address who);
    event TokenRetrieveUnclaimedFunds(address tokenWallet, address who);

    /* 9. Contract has method token deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his token unless they are processed by the contract owner (11.) */
    function tokenDeposit(address tokenWallet, uint amount) public {
        /* Contract checks that method invocation attaches non-zero value. */
        require(amount > 0);

        /* Contract checks that token in whitelist */
        require(whitelistTokenWallets[tokenWallet]);

        /* Contract checks that `DEADLINE` is not reached. */
        require(block.number <= deadline);

        /* msg.sender initiate transferFrom function from ERC20 contract */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transferFrom(msg.sender, this, amount));

        /* Contract adds value sent to the corresponding mapping stored in token DEPOSIT using sender as a key */
        tokenDeposits[tokenWallet][msg.sender] = tokenDeposits[tokenWallet][msg.sender].add(amount);
        TokenDeposit(tokenWallet, msg.sender, amount);
    }

    /* 10. Contract has method token withdraw without amount argument */
    /* Ability to withdraw funds for participant which he earlier had put in the contract using deposit function (9.) */
    function tokenWithdraw(address tokenWallet) public {
        /* Contract checks that balance of the sender in token DEPOSITS mapping is equal amount */
        require(tokenDeposits[tokenWallet][msg.sender] > 0);

        uint256 tokenBalance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets the amount in corresponding record in token DEPOSITS mapping to zero */
        tokenDeposits[tokenWallet][msg.sender] = 0;

        /* Contract transfers amount to the sender from it's own token balance */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(msg.sender, tokenBalance));

        TokenWithdrawal(tokenWallet, msg.sender);
    }

    /* 11. Contract has method token process */
    /* Sender does final confirmation that his tokens will be used in the Token Sale */
    function tokenProcess(address tokenWallet) public {
        /* Contract checks if value of token DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(tokenDeposits[tokenWallet][msg.sender] > 0);
        require(whitelistUsers[msg.sender]);

        uint256 balance = tokenDeposits[tokenWallet][msg.sender];
        /* Contract sets balance of the sender entry to zero in the token DEPOSITS */
        tokenDeposits[tokenWallet][msg.sender] = 0;

        /* Contract transfers tokens to the WALLET */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(wallet, balance));

        TokenProcess(tokenWallet, msg.sender);
    }

    /* 12. Contract has method tokenRetrieveUnclaimedFunds with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function tokenRetrieveUnclaimedFunds(address tokenWallet, address who) public onlyOwner {
        require(who != address(0));

        /* Contract checks if current block.number is later than DEADLINE */
        require(block.number > deadline);

        /* Contract checks if token DEPOSIT mapping with key equal to address argument has non-zero balance */
        require(tokenDeposits[tokenWallet][who] > 0);

        uint256 balance = tokenDeposits[tokenWallet][who];

        /* Contract sets balance of token DEPOSIT mapping to zero */
        tokenDeposits[tokenWallet][who] = 0;

        /* Contract transfers tokens to the WALLET */
        ERC20Interface ERC20Token = ERC20Interface(tokenWallet);
        require(ERC20Token.transfer(owner, balance));

        TokenRetrieveUnclaimedFunds(tokenWallet, who);
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
