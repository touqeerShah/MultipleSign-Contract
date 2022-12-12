// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract MultiSigWallet {
    // events
    event Deposit(address indexed sender, uint amount, uint balance);
    event ApplyForOwner(address indexed newowner);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    // variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public minAmount;

    uint public numConfirmationsRequired;
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    struct NewOwner {
        address payable newowner;
        bool executed;
        uint numConfirmations;
        uint numDeny;
    }
    // mapping from tx index => owner => bool

    mapping(uint => mapping(address => bool)) public isConfirmed;
    mapping(address => mapping(address => bool)) public isVoted;

    mapping(address => uint) public depositAmount;
    mapping(address => NewOwner) public newOwners;

    Transaction[] public transactions;
    // NewOwner[] public newOwners;

    // modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }
    modifier newOwnerExist(address _newOwnerIndex) {
        require(
            newOwners[_newOwnerIndex].newowner != address(0),
            "tx does not exist"
        );
        _;
    }
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }
    modifier noDecisionMade(address _newOwnerIndex) {
        require(!newOwners[_newOwnerIndex].executed, "Decision is made");
        _;
    }
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }
    modifier notVoted(address _newOwnerIndex) {
        require(!isVoted[_newOwnerIndex][msg.sender], "yo already Vote for it");
        _;
    }

    constructor(uint _minAmount) payable {
        require(
            _minAmount > 0 && msg.value == _minAmount,
            "invalid number of required confirmations"
        );
        require(!isOwner[msg.sender], "owner not unique");
        minAmount = _minAmount;
        isOwner[msg.sender] = true;
        owners.push(msg.sender);

        depositAmount[msg.sender] = msg.value;
        numConfirmationsRequired = 1;
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param _to Transaction target address.
    /// @param _value Transaction ether value.
    /// @param _data Transaction data payload.
    /// @return txIndex Returns a txIndex.
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner returns (uint txIndex) {
        txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /// @dev New user can request for become owner
    function applyForOwner() public payable {
        require(!isOwner[msg.sender], "Already Owner");
        require(
            msg.value == minAmount,
            "invalid amount need Min Amount for apply"
        );
        newOwners[msg.sender] = (
            NewOwner({
                newowner: payable(msg.sender),
                executed: false,
                numConfirmations: 0,
                numDeny: 0
            })
        );
        depositAmount[msg.sender] = msg.value;
        emit ApplyForOwner(msg.sender);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param _newOwner Transaction ID.
    function voteForNewOwner(
        address _newOwner,
        bool isAccepte
    )
        public
        onlyOwner
        newOwnerExist(_newOwner)
        newOwnerExist(_newOwner)
        notVoted(_newOwner)
    {
        NewOwner storage ownerCandidate = newOwners[_newOwner];
        if (isAccepte) ownerCandidate.numConfirmations += 1;
        if (!isAccepte) ownerCandidate.numDeny += 1;
        isVoted[_newOwner][msg.sender] = true;
        if (ownerCandidate.numConfirmations >= numConfirmationsRequired) {
            owners.push(ownerCandidate.newowner);
            ownerCandidate.executed = true;
        } else if (ownerCandidate.numDeny >= numConfirmationsRequired) {
            ownerCandidate.executed = true;
            (bool success, ) = ownerCandidate.newowner.call{
                value: depositAmount[ownerCandidate.newowner]
            }("");
            require(success, "tx failed");
        }
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param _txIndex Transaction ID.
    function confirmTransaction(
        uint _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param _txIndex Transaction ID.
    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param _txIndex Transaction ID.
    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /// @dev Returns list of owners.
    /// @return owners List of owner addresses.
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @dev Returns transaction count.
    /// @return number of transactions.
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /// @dev Returns transaction by txIndex giving the to,value, data, executed, numConfirmations the transactions deailts
    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
