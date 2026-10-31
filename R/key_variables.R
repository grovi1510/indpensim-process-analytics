# Control loops (CV / MV / disturbance-demand). P is the outcome, not monitored.
loops <- list(
  temperature = list(cv = "T",   mv = c("Fc", "Fh"), dist = "Q"),
  pH          = list(cv = "pH",  mv = c("Fb", "Fa"), dist = "CER"),
  oxygen      = list(cv = "DO2", mv = "Fg",          dist = "OUR")
)

# M1 control-chart set
key_vars   <- c("pH", "T", "Fb", "DO2", "CER")
fixed_lim  <- c("pH", "T")          # controlled: fixed limits
varying_lim <- c("Fb", "DO2", "CER") # trajectory-shaped: time-varying limits