//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author     : Trung Pham
// Description: Common macros for project
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

`ifndef PRIM
`define PRIM

`define PRIM_FF_RST(OUT, IN, RST, CLK, RST_VAL='0)    \
    always_ff @( posedge CLK ) begin : \prim_ff_``OUT \
        if (RST) begin                                \
            OUT <= RST_VAL;                           \
        end                                           \
        else begin                                    \
            OUT <= IN;                                \
        end                                           \
    end                                                 

`define PRIM_FF_EN_RST(OUT, IN, EN, RST, CLK, RST_VAL='0) \
    always_ff @( posedge CLK ) begin : \prim_ff_``OUT     \
        if (RST) begin                                    \
            OUT <= RST_VAL;                               \
        end                                               \
        else begin                                        \
            OUT <= (EN) ? IN : OUT;                       \
        end                                               \
    end                                                 

// Input : 'b000110
// Output: 'b000010
`define PRIM_FIRST_RIGHT_1(OUT, IN)                 \
    always_comb begin: \prim_first_right_1_``OUT    \
        OUT = $bits(IN)'(~IN + $bits(IN)'(1)) & IN; \
    end 

// Input : 'b000110
// Output: 'b000100
`define PRIM_FIRST_LEFT_1(OUT, IN)                                                                        \
    logic [$bits(OUT)-1:0] \REVERSE_``OUT ;                                                               \
    always_comb begin: \prim_first_right_1_``OUT                                                          \
        \REVERSE_``OUT = {<<{IN}};                                                                        \
        OUT = $bits( \REVERSE_``OUT )'(~ \REVERSE_``OUT + $bits( \REVERSE_``OUT )'(1)) & \REVERSE_``OUT ; \
        OUT = {<<{OUT}};                                                                                  \
    end 

`endif

// Input : 'b010100
// Output: 'b111100
`define PRIM_EXTEND_1(OUT, IN)                      \
    always_comb begin: \prim_extend_1_``OUT         \
        OUT = $bits(IN)'(~IN + $bits(IN)'(1)) | IN; \
    end 

// Input : 'b010100
// Output: 'b111000
`define PRIM_EXTEND_1_AFTER(OUT, IN)                \
    always_comb begin: \prim_extend_1_after_``OUT   \
        OUT = $bits(IN)'(~IN + $bits(IN)'(1)) ^ IN; \
    end 

// Input : 'b000100 (Input must be onehot)
// Output: 'b111000
`define PRIM_EXTEND_1_ONEHOT(OUT, IN)                                   \
    logic [$bits(OUT)-1:0] \REVERSE_``OUT ;                             \
    always_comb begin: \prim_extend_1_onehot_``OUT                      \
        \REVERSE_``OUT = {<<{IN}};                                      \
        \REVERSE_``OUT = $bits(OUT)'( \REVERSE_``OUT - $bits(OUT)'(1)); \
        OUT = {<<{ \REVERSE_``OUT }};                                   \
    end 