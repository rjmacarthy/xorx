pub const RoutingTableError = error{
    NoSpace,
    OutOfMemory,
    Overflow,
    InvalidEnd,
    InvalidCharacter,
    Incomplete,
    NonCanonical,
};

