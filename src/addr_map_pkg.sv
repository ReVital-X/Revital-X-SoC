package addr_map_pkg;

    typedef logic [3:0]  apb_idx_t;
    typedef logic [31:0] apb_addr_t;

    typedef struct packed {
        apb_idx_t  idx;
        apb_addr_t start_addr;
        apb_addr_t end_addr;
    } addr_rule_t;

    // End address is exclusive.
    localparam addr_rule_t GPIO_RULE =
        '{idx: 0, start_addr: 32'h4000_0000, end_addr: 32'h4000_1000};

    localparam addr_rule_t I2C_RULE =
        '{idx: 1, start_addr: 32'h4000_1000, end_addr: 32'h4000_2000};

    localparam addr_rule_t SPI_RULE =
        '{idx: 2, start_addr: 32'h4000_2000, end_addr: 32'h4000_3000};

    localparam addr_rule_t TIMER_RULE =
        '{idx: 3, start_addr: 32'h4000_3000, end_addr: 32'h4000_4000};

endpackage : addr_map_pkg
