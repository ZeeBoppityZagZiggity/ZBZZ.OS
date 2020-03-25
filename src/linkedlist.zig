const kmem = @import("kmem.zig"); 

pub fn LinkedList(comptime T: type) type {
    return packed struct {
        pub const Node = packed struct {
            data: T, 
            prev: ?*Node, 
            next: ?*Node, 
            
        };

        first: ?*Node = null, 
        last: ?*Node = null, 
        len: usize = 0,

        pub fn push_front(self: *LinkedList(T), d: T) void {
            if (self.first == null) {
                var n = Node {
                    .prev = null,
                    .next = null, 
                    .data = d,
                }; 
                self.*.first = &n;
                self.*.last = &n; 
                self.*.len = 1;
                // self = LinkedList(T) {
                //     .first = n, 
                //     .last = n, 
                //     .len = 1,
                // };
            } else {
                var n = Node {
                    .prev = null, 
                    .next = self.*.first, 
                    .data = d, 
                }; 
                self.*.first.?.*.prev = &n; 
                self.*.first = &n;
                self.*.len += 1;
            }
        }

        pub fn pop_front(self: *LinkedList(T)) T {
            var retval = self.*.first.?.*.data; 
            self.*.len -= 1; 
            if (self.*.len > 0) {
                self.*.first = self.*.first.?.*.next; 
                return retval;
            } else {
                self.*.first = null;
                self.*.last = null;
            }
            return retval;
        }

        pub fn push_back(self: *LinkedList(T), d: T) void {
            if (self.last == null) {
                var n = Node {
                    .prev = null, 
                    .next = null, 
                    .data = d,
                }; 
                self.*.first = &n; 
                self.*.last = &n; 
                self.*.len = 1;
            }
        }

        pub fn addlen(self: *LinkedList(T), i: usize) void {
            // self = LinkedList(T) {
            //     .first = self.first,
            //     .last = self.last, 
            //     .len = self.len + i,
            // }; 
            self.*.len = self.*.len + i;
        } 
    };
}

// pub const Node = struct {
//     prev: ?*Node = null,
//     next: ?*Node = null, 
//     data: usize = 0,
// }; 

// pub const LinkedList = struct {
//     head: ?*Node, 
//     tail: ?*Node, 

//     pub fn initList() LinkedList {
//         var ret_list = LinkedList {
//             .head = null, 
//             .tail = null
//         };
//         return ret_list; 
//     }

//     pub fn push_front(self: LinkedList, d: usize) {
//         if (self.head == null) {
//             var n = Node {
//                 .prev = null, 
//                 .next = null, 
//                 .data = d 
//             };
//             self.head = &n;
//             self.tail = &n; 
//         } else {
//             var n = Node {
//                 .prev = null, 
//                 .next = &self.head, 
//                 .data = d
//             }; 
//             self.head.?.*.prev = &n;
//         }

//     }
// }

