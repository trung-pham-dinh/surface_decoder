`timescale 1ns/1ns
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Testbench for logical_bit with a live ASCII torus renderer.
//
// node  = *NN/p*  -> NN=cid, p=cpar, *=syndrome set
//
// Every PE-PE edge is a PAIR of half-edges (one per PE).
//   Horizontal: side by side on one line, 2 chars {L}{R}
//        L = left PE out_erasure_right , R = right PE out_erasure_left
//        =  active   .  inactive   ->  ==  =.  .=  ..
//   Vertical: stacked on two lines (an edge is drawn tall)
//        upper line = top PE out_erasure_bot
//        lower line = bottom PE out_erasure_top
//        ||  active   ..  inactive
//        both:  ||     top only: ||     bottom only: ..
//               ||               ..                  ||
//
// Periodic edges are drawn inline with the same symbols:
//   right boundary  = the last horizontal connector on each row (wraps to j00)
//   bottom boundary = the vertical gap after the last row       (wraps to i00)
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
module logical_bit_sim
    import common_pkg::*;
();
    localparam int L          = TORUS_L;
    localparam int MAX_CYCLES = 60;

    logic           clk = 0;
    logic           rst = 1;
    logic           start = 0;
    logic [L*L-1:0] syndrome_update = '0;
    logic [L*L-1:0] syndrome;
    logic [L*L-1:0] or_erasure_edges;

    logical_bit uut (
        .clk                     (clk             ),
        .rst                     (rst             ),
        .start                   (start           ),
        .syndrome_update_flatten (syndrome_update ),
        .syndrome_flatten        (syndrome        ),
        .or_erasure_edges_flatten(or_erasure_edges)
    );

    //-------------------------------------------------------------
    // Capture per-PE internals into 2-D arrays (generate-bind).
    //-------------------------------------------------------------
    cid_t cidA [L][L];
    logic cparA[L][L];
    logic synA [L][L];
    logic erLA [L][L], erRA[L][L], erTA[L][L], erBA[L][L];

    generate
        for (genvar gi = 0; gi < L; gi++) begin : cap_row
            for (genvar gj = 0; gj < L; gj++) begin : cap_col
                `define PE uut.torus.g_lattice_row[gi].g_lattice_col[gj].u_pe
                assign cidA [gi][gj] = `PE.self_cid;
                assign cparA[gi][gj] = `PE.self_cpar;
                assign synA [gi][gj] = `PE.syndrome;
                assign erLA [gi][gj] = `PE.out_erasure_left;
                assign erRA [gi][gj] = `PE.out_erasure_right;
                assign erTA [gi][gj] = `PE.out_erasure_top;
                assign erBA [gi][gj] = `PE.out_erasure_bot;
                `undef PE
            end
        end
    endgenerate

    //-------------------------------------------------------------
    // Rendering helpers (plain ASCII only)
    //-------------------------------------------------------------
    function automatic string node_str(int i, int j);
        string c, p, mk;
        c  = $isunknown(cidA [i][j]) ? "??" : $sformatf("%02d", cidA[i][j]);
        p  = $isunknown(cparA[i][j]) ? "x"  : $sformatf("%0d",  cparA[i][j]);
        mk = (synA[i][j] === 1'b1)   ? "*"  : " ";
        return $sformatf("%s%s/%s%s", mk, c, p, mk);            // 6 chars
    endfunction

    // horizontal half-edge pair between (i,j) and (i,(j+1)%L): 2 chars
    function automatic string hedge_str(int i, int j);
        return {erRA[i][j] ? "=" : ".", erLA[i][(j+1)%L] ? "=" : "."};
    endfunction

    // one 6-wide vertical block: "||" if active else ".."
    function automatic string vblk(bit on);
        return on ? "  ||  " : "  ..  ";
    endfunction

    // vertical gap between top-row ti and bottom-row bi -> two stacked lines
    task automatic print_vgap(int ti, int bi);
        string su, sl;
        su = "   ";                                   // upper: top PE out_erasure_bot
        sl = "   ";                                   // lower: bottom PE out_erasure_top
        for (int j = 0; j < L; j++) begin
            su = {su, vblk(erBA[ti][j])};
            sl = {sl, vblk(erTA[bi][j])};
            if (j < L-1) begin su = {su, "  "}; sl = {sl, "  "}; end
        end
        $display("%s", su);
        $display("%s", sl);
    endtask

    task automatic draw_torus(input string tag = "");
        string s;
        $display("");
        $display("==== TORUS  t=%0t  %s ====", $time, tag);
        s = "   ";
        for (int j = 0; j < L; j++) s = {s, $sformatf("  j%02d   ", j)};
        $display("%s", s);

        for (int i = 0; i < L; i++) begin
            // node row; last connector (j=L-1) is the right-boundary wrap
            s = $sformatf("i%02d", i);
            for (int j = 0; j < L; j++) begin
                s = {s, node_str(i, j)};
                s = {s, hedge_str(i, j)};
            end
            $display("%s", s);
            if (i < L-1) print_vgap(i, i+1);          // interior vertical gap
        end
        print_vgap(L-1, 0);                            // bottom-boundary wrap
    endtask

    //-------------------------------------------------------------
    // Clock / stimulus
    //-------------------------------------------------------------
    initial $timeformat(-9, 0, " ns", 0);
    initial forever #5 clk = ~clk;

    initial begin
        #20; rst = 0;
        #10; syndrome_update[18] = 1'b1;
             syndrome_update[27] = 1'b1;
             syndrome_update[26] = 1'b1;
             syndrome_update[45] = 1'b1;
             syndrome_update[54] = 1'b1;
             syndrome_update[53] = 1'b1;
        #10; syndrome_update[18] = 1'b0;
             syndrome_update[27] = 1'b0;
             syndrome_update[26] = 1'b0;
             syndrome_update[45] = 1'b0;
             syndrome_update[54] = 1'b0;
             syndrome_update[53] = 1'b0;


        #10; start = 1'b1;
    end

    int cyc = 0;
    always @(negedge clk) begin
        if (!rst) begin
            draw_torus($sformatf("state=%0d start=%0b", uut.pe_state, start));
            cyc++;
            if (cyc >= MAX_CYCLES) begin
                $display("\n-- reached MAX_CYCLES, finishing --");
                $finish;
            end
        end
    end

    initial begin
        $display("legend: node=*NN/p* (NN=cid p=cpar *=syndrome)");
        $display("        horiz {L}{R}: = active . inactive (== both, =. left, .= right)");
        $display("        vert stacked : upper=top.out_B  lower=bot.out_T  (|| active, .. inactive)");
        $display("        last h-connector = right wrap; vgap after last row = bottom wrap");
        $display("        state: 0=IDLE 1=GROW 2=MERGE 3=SPREAD");
    end
endmodule