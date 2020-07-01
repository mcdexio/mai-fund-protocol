pragma solidity 0.6.10;

library LibOrderbook {

    bytes32 private constant NO_VALUE = "";

    struct ShareOrder {
        uint256 id;
        uint256 index;
        uint256 filled;
        address trader;
        address amount;
        uint256 slippage;
        uint256 availableAt;
    }

    struct ShareOrderbook {
        uint256 nextId;
        // index => id
        uint256[] orderList;
        // id => order
        mapping(uint256 => ShareOrder) orders;
    }

    function getNextId(ShareOrderbook storage orderbook) internal returns (uint256) {
        uint256 newId = orderbook.nextId;
        orderbook.nextId++;
        return newId;
    }

    function getOrder(ShareOrderbook storage orderbook, uint256 id) internal view returns (ShareOrder memory) {
        return orderbook.orders[id];
    }

    function isEmpty(ShareOrderbook storage orderbook) internal view returns (bool) {
        return orderbook.orderList.length == 0;
    }

    function has(ShareOrderbook storage orderbook, uint256 id) internal view returns (bool) {
        return orderbook.orders[id].trader != address(0);
    }

    function add(ShareOrderbook storage orderbook, ShareOrder memory newOrder) internal {
        require(!has(orderbook, newOrder.id), "duplicated id");
        require(newOrder.trader != address(0), "trader cannot be 0");
        newOrder.index = orderbook.orderList.length;
        orderbook.orders[newOrder.id] = newOrder;
        orderbook.orderList.push(newOrder.id);
    }

    function remove(ShareOrderbook storage orderbook, uint256 id) internal {
        require(has(orderbook, id), "order id not exist");

        ShareOrder memory order = orderbook.orders[id];
        uint256 lastIndex = orderbook.orderList.length - 1;
        uint256 lastId = orderbook.orderList[lastIndex];
        orderbook.orders[lastId].index = order.index;
        orderbook.orderList[order.index] = lastId;

        delete orderbook.orders[lastIndex];
        orderbook.orderList.pop();
    }
}