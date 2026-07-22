//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Author     : Trung Pham
// Description: Common packages for project
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

package common_pkg;

    //// shared parameters
    localparam TORUS_L = 8;
    localparam int CID_BITS = $clog2(TORUS_L**2 + 1);
    //parameter int DATA_WIDTH = 64;

    //// shared enum
    //typedef enum logic [1:0] {
    //    READ  = 2'b00,
    //    WRITE = 2'b01,
    //    IDLE  = 2'b10
    //} cmd_e;

    // shared types
    // cid: cluster_id
    typedef logic [CID_BITS-1:0] cid_t;

    localparam cid_t NON_CID = cid_t'('1); // non-valid largest CID

    typedef enum logic [1:0] { 
        PE_IDLE,
        PE_GROW,
        PE_SPREAD
    } pe_state_e;

    typedef struct packed {
        cid_t dst; // changed to
        cid_t src; // effected
    } spread_cid_t;


    typedef struct packed {
        spread_cid_t spread_out_connect_cid;
        logic        spread_out_connect_parity;
    } pe_status_t;

endpackage
