// const proc = @import("process.zig"); 
const kmem = @import("kmem.zig");


pub const Node = packed struct {
    // P: proc.Process = undefined,
    data: usize = undefined,
    next: ?*Node = null,

    pub fn new(d: usize) *Node {
        var node_ptr_u8 = kmem.kzmalloc(@sizeOf(Node)); 
        var node_ptr = @ptrCast(*Node, node_ptr_u8); 
        node_ptr.*.data = d;
        node_ptr.*.next = null; 
        return node_ptr;
        // return Node{
        //     .data = d,
        //     .next = null
        // };
    }

};

pub fn push(head: *Node, d: usize) void {
    var new_head_ptr = kmem.kzmalloc(@sizeOf(Node)); 
    var new_head = @ptrCast(*Node, new_head_ptr); 
    new_head.*.data = d; 
    new_head.*.next = head; 
    var head_ptr = &head; 
    head_ptr.* = new_head;
}

// pub const procList = struct {
//     head: *Node = undefined,

//     pub fn init(h: *Node) procList {
//         return procList{
//             .head = h
//         };
//     }

//     pub fn push(self: ProcList, p: *Node) void {
//         p.*.next = self.head; 
//         self.head.*.prev = p; 
//         self = procList{.head = p};
//     }

//     pub fn pop(self: ProcList) Node {
//         var retval = self.head.*.data; 
//         self.head.*.next.*.prev = null;
//         self = procList{.head = self.head.*.next}; 
//         return retval;
//     }
// };
