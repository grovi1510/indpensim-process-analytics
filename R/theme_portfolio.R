pal <- poison_palette("Opuyama", return = "vector")

col_ref   <- pal[1]               # #9AAEB0 background / reference batches
col_strat <- c(recipe    = pal[2],  # #0086A1 teal
               operator  = pal[3],  # #214F6D navy
               apc_raman = pal[4],  # #451A0E dark brown
               fault     = pal[5])  # #010100 black

theme_set(theme_minimal(base_size = 11) +
            theme(plot.title.position = "plot",
                  legend.position = "bottom"))