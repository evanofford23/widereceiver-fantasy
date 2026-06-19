library(tidyverse)
library(nflverse)
library(ggrepel)


#* The function wr_sum_stats collects various helpful summary statistics for 
#* wide receivers in the season indicated, including targets per game, target
#* share and fantasy points per game. We only include receivers who have at 
#* least 30 targets in that season.

wr_sum_stats <- function(year) {
  wr_stats <- nflreadr::load_player_stats(year) %>%
    filter(season_type == "REG" & position == "WR")
  wr_stats %>%
    group_by(player_display_name) %>%
    summarize(
      gp = n(),
      tot_receptions = sum(receptions),
      tot_targets = sum(targets),
      tot_yards = sum(receiving_yards) + sum(rushing_yards),
      tot_tds = sum(receiving_tds) + sum(rushing_tds),
      tot_fums = sum(receiving_fumbles_lost) + sum(rushing_fumbles_lost),
      tot_air_yards = sum(receiving_air_yards),
      tot_yac = sum(receiving_yards_after_catch),
      avg_target_share = mean(target_share),
      avg_air_yards_share = mean(air_yards_share),
      avg_yac = tot_yac/tot_receptions) %>%
    mutate(fan_pts = 0.1*tot_yards + 6*tot_tds + tot_receptions - 2*tot_fums,
           avg_fpts = fan_pts/gp, avg_targets = tot_targets/gp) %>%
    filter(tot_targets > 30) %>%
    select(player_display_name, gp, tot_receptions, tot_targets, tot_yards, 
           tot_tds, tot_fums, tot_air_yards, tot_yac, avg_target_share, 
           avg_air_yards_share, fan_pts, avg_yac, avg_fpts, avg_targets)
}


#* The function top_players takes the top 24 wide receivers in terms of 
#* fantasy points scored per game.

top_players <- function(year, num = 24) {
  wr_sum_stats(year) %>%
    arrange(desc(avg_fpts)) %>%
    head(n = num) %>%
    mutate(short_name = word(player_display_name, 2))
}


# Get data for fitting model and graphing
wr_data <- wr_sum_stats(2025)
top24 <- top_players(2025)
top24$short_name[4] <- "St. Brown" # for 2025 and 2023
top24$short_name[15] <- "G. Wilson" # for 2025
top24$short_name[20] <- "M. Wilson" # for 2025
# top24$short_name[6] <- "St. Brown" # for 2024

# Fit regression model
model <- lm(avg_fpts ~ avg_targets, data = wr_data)

# Add expected fantasy points and residuals
top24 <- top24 %>%
  mutate(
    expected_fpts = predict(model, .),
    over_expected = avg_fpts - expected_fpts,
    
    performance = case_when(
      over_expected > 1.25 ~ "Overperforming",
      over_expected < -1.25 ~ "Underperforming",
      TRUE ~ "As Expected"
    ),
    
    label = short_name
  )

# Plot
ggplot(
  top24,
  aes(
    x = avg_targets,
    y = avg_fpts,
    color = performance
  )
) +
  
  geom_point(
    size = 4,
    alpha = 0.85
  ) +
  
  geom_text_repel(
    aes(label = label),
    size = 5,
    box.padding = 0.25,
    point.padding = 0.15,
    max.overlaps = Inf
  ) +
  
  geom_smooth(
    data = wr_data,
    aes(x = avg_targets, y = avg_fpts),
    method = "lm",
    color = "black",
    linewidth = 1.2,
    se = FALSE
  ) +
  scale_x_continuous(limits = range(top24$avg_targets)) +
  
  scale_color_manual(
    values = c(
      "Overperforming" = "forestgreen",
      "As Expected" = "grey20",
      "Underperforming" = "firebrick"
    )
  ) +
  
  labs(
    title = "Fantasy Production vs. Target Volume 2025", # must be changed for year
    subtitle = "Top 24 WRs by fantasy points per game, 2025 NFL season",
    x = "Targets Per Game",
    y = "Fantasy Points Per Game",
    color = NULL,
    caption = "Source: nflverse"
  ) +
  
  theme_classic(base_size = 13) +
  
  theme(
    plot.title = element_text(
      size = 22,
      face = "bold"
    ),
    
    plot.subtitle = element_text(
      size = 14
    ),
    
    axis.title = element_text(
      size = 14,
      face = "bold"
    ),
    
    axis.text = element_text(
      size = 12
    ),
    
    legend.position = "top",
    
    plot.caption = element_text(
      size = 10,
      color = "grey25"
    ),
    
    plot.margin = margin(
      t = 15,
      r = 20,
      b = 15,
      l = 15
    )
  )


# Save for GitHub

ggsave(
  "fantasy_production_vs_target_volume2025.png", # change for year
  width = 12,
  height = 7,
  dpi = 300
)
