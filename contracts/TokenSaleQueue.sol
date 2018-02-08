pragma solidity 0.4.19;

/* 1. Contract is initiated by storing sender as OWNER and with two arguments deadline : timestamp which is also stored as DEADLINE and wallet : address which is also stored as WALLET. */
/* Only owner is eglible to perform core functions like authorizing participants as confirmed investors and withdrawing their money as Token sale funds. */
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

    /* 2. Contract has internal mapping DEPOSITS : Address -> (balance: Uint, authroized: bool) representing balance of everyone whoever used deposit method */
    /* This is where balances of all participants stored. Additional flag of whether the participant is authorized investor is stored. This flag determines if the participant funds can be further processed by the contract OWNER (see 5., 6.) */
    struct Record {
        uint256 balance;
        bool authroized;
    }

    mapping(address => Record) public deposits;
    address public wallet;
    uint256 public deadline; /* blocks */

    function balanceOf(address who) public view returns (uint256 balance) {
        return deposits[who].balance;
    }

    function isAuthorized(address who) public view returns (bool authroized) {
        return deposits[who].authroized;
    }

    function getWallet() public view returns (address) {
        return wallet;
    }

    function getDeadline() public view returns (uint) {
        return deadline;
    }

    event Deposit(address who, uint256 amount);
    event Withdrawal(address who);
    event Authorized(address who);
    event Process(address who);
    event Refund(address who);

    function TokenSaleQueue(address _wallet, uint _deadline) public {
        wallet = _wallet;
        deadline = _deadline;
        owner = msg.sender;
    }

    /* 3. Contract has payable method deposit */
    /* This is how participant puts his funds in the queue for further processing. Participant can later withdraw his funds unless they are processed by the conract owner (6.) */
    function deposit() public payable {
        /* Contract checks that method invocation attaches non-zero value. */
        require(msg.value > 0);
        /* Contract checks that `DEADLINE` is not reached. If it is reached, it returns all funds to `sender` */
        require(block.number <= deadline);
        
        /* Contract adds value sent to the corresponding mapping stored in DEPOSIT using sender as a key */
        deposits[msg.sender].balance = deposits[msg.sender].balance.add(msg.value);
        Deposit(msg.sender, msg.value);
    }

    /* 4. Contract has method withdraw with amount argument */
    /* Ability to withdraw funds for participant which he eariler had put in the contract using deposit function (1.) */
    function withdraw(uint256 amount) public {
        /* Contract checks that method invocation attaches non-zero value */
        require(amount > 0);
        
        /* Contract checks that balance of the sender in DEPOSITS mapping is equal amount */
        Record storage record = deposits[msg.sender];
        require(record.balance == amount);
        
        /* Contract sets the amount in corresponding record in DEPOSITS mapping to zero */
        record.balance = 0;
        
        /* Contract transfers amount to the sender from it's own balance */
        msg.sender.transfer(amount);
        Withdrawal(msg.sender);
    }

    /* 5. Contract has method authorize with address argument */
    /* Owner authorizes particular participant - operation that allows to use participant money in Token sale */
    function authorize(address who) public onlyOwner {
        /* Contract checks if sender is equal to OWNER */
        require(who != address(0));
        
        Record storage record = deposits[who];
        require(record.balance > 0);
        
        /* Contract updates corresponding value in DEPOSITS mapping using address as the key and sets authorized = true */
        record.authroized = true;
        Authorized(who);
    }

    /* 6. Contract has method process */
    /* Sender does final confirmation that his money will be used in the Token sale */
    function process() public {
        Record storage record = deposits[msg.sender];

        /* Contract checks if value of DEPOSITS with sender key has non-zero balance and authorized is set true */
        require(record.balance > 0);
        require(record.authroized);

        uint256 balance = record.balance;
        /* Contract sets balance of the sender entry to zero in the DEPOSITS */
        record.balance = 0;
        
        /* Contract transfers balance to the WALLET */
        wallet.transfer(balance);

        Process(msg.sender);
    }

    /* 7. Contract has method refund with address argument */
    /* Owner can force contract to return participant funds back to the participants when the DEADLINE is reached */
    function refund(address who) public onlyOwner {
        /* Contract checks if sender is OWNER */
        require(who != address(0));
        /* Contract checks if current timestamp is later than DEADLINE */
        require(block.number > deadline);
        
        /* Contract picks the record in DEPOSIT mapping with key equal to address argument (RECORD) */
        Record storage record = deposits[who];
        /* Contract checks if RECORD has non-zero balance */
        require(record.balance > 0);
        
        uint256 balance = record.balance;
        /* Contract sets balance of RECORD to zero */
        record.balance = 0;
        /* Contract sends funds from it's own balance to owner */
        owner.transfer(balance);

        Refund(who);
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
