# load ----
source('r/helper.r') 

# harvest by year and permit type
# AHO from management memo

ssei_aho <- data.frame(year = c(1985, 1986, 1987, 1988, 1989, 1990, 1991, 1992, 
                                1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000, 
                                2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008,
                                2009, 2010, 2011, 2012, 2013, 2014,2015, 2016, 
                                2017, 2018, 2019),
                       aho = c(rep(790000, 13), 632000, 720000, rep(696000, 9),
                               634000, 634000, 583280, 583280, 583280, 536618, 
                               536618, 482956, 516763, 578774, 607713))

# data ----

read_xlsx("data/SSEI fishticket data.xlsx") %>% 
  rename_all(tolower) %>% 
  filter(species_code == 710, harvest_code != 43) -> fishery_df

read_xlsx("data/SSEI pot logbook data.xlsx") %>% 
  rename_all(tolower) -> pot_log_df

read_xlsx("data/SSEI longline logbook data.xlsx") %>% 
  rename_all(tolower) -> ll_log_df

read_excel("data/ssei longline sablefish lbs per set.xlsx") %>% 
  rename_all(tolower) -> ll_set_df

read_csv("data/ssei survey hook accounting.csv") %>% 
  rename_all(tolower) -> hooks_df

read_excel("data/SSEI LL survey bio data.xlsx") %>% 
  rename_all(tolower) -> svy_bio_df

read.csv("data/SSEI port sampling data.csv", header = TRUE) %>% 
  rename_all(tolower) -> fish_bio_df

# harvest by year and permit type ----

fishery_df %>% 
  filter(gear_code %in% c(61, 91)) %>% 
  full_join(ssei_aho) %>% 
  group_by(year) %>% 
  summarise(total_harvest = sum(round_pounds),
            aho = mean(aho)) %>% 
  mutate(mgmt_type = ifelse(year %in% 1985:1996, "Limited Entry", "Equal Quota Share")) -> harvest

xaxis <- FNGr::tickr(harvest, year, 3)

ggplot(harvest, aes(year, total_harvest)) + 
  geom_bar(stat = "identity", aes(fill = mgmt_type)) +
  geom_line(aes(y = aho), linetype = 3) +
  ylab("Harvest (round lbs)\n") + xlab("\nYear") +
  scale_x_continuous(breaks = xaxis$breaks, labels=xaxis$labels) +
  scale_y_continuous(label = scales::comma)+
  scale_fill_grey() +
  theme(legend.position = c(0.75, 0.85), legend.title = element_blank())

ggsave('figures/ssei_fishery_harvest.png', width = 6.5, height = 5, units = "in", dpi = 200)

# Harvest distribution by area ----

fishery_df %>% 
  filter(g_stat_area != 1065, 
         g_management_area_code == "SSEI", year >= 1997) %>%
  mutate(Area = case_when(g_stat_area %in% c(325431, 315431, 325401, 315401) ~ "Dixon Entrance",
                          g_stat_area %in% c(305431, 305501, 305502, 305503, 315432, 315501,
                                             315502, 315503, 315504, 325433, 325501, 325502,
                                             325503, 325504) ~ "Lower Clarence Strait",
                          g_stat_area %in% c(305531, 305532, 315531, 315532, 325531, 325532,
                                             325533, 335506, 335534, 335535) ~ "Upper Clarence Strait",
                          g_stat_area %in% c(315600, 325601, 325602, 325603, 325604, 325631, 325632,
                                             335533, 335601, 335602, 335603, 335632, 335633, 345535,
                                             345604) ~ "Sumner Strait",
                          TRUE ~ "Other")) %>%
  group_by(year, Area) %>% 
  summarise(total_harvest = sum(round_pounds), 
            permit_count = n_distinct(cfec_no)) %>% 
  mutate(Area = factor(Area, 
                       levels = c("Sumner Strait", "Upper Clarence Strait", 
                                  "Lower Clarence Strait", "Dixon Entrance"))) %>% 
  filter(permit_count >= 3) %>% 
ggplot(aes(year, total_harvest, fill = Area)) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_grey() + 
  ylab("Total Harvest (round lbs)\n") + 
  xlab("\nYear") +
  scale_x_continuous(breaks = xaxis$breaks, labels=xaxis$labels) +
  scale_y_continuous(labels = scales::comma, breaks = seq(0, 700000, 100000)) +
  theme(legend.position = c(0.75, 0.88), legend.title = element_blank())

ggsave("figures/SSEI_Fishery_Harvest_Distribution.png", width = 6.5, 
       height = 5, units = "in", dpi = 200)

# pot fishery cpue ----

fishery_df %>% 
  left_join(pot_log_df) %>% 
  filter(gear=='Pot') %>% 
  group_by(year) %>% 
  mutate(cpue = round_pounds / n(), 
         permit_count = n_distinct(cfec_no)) %>% 
  filter(permit_count >= 3) %>% 
  summarise(sd = sd(cpue),
            cpue = mean(cpue),
            n = n(),
            se = sd / sqrt(n)) %>% 
  mutate(ll = cpue - 2 * se,
         ul = cpue + 2 * se) %>% 
  ggplot(aes(year, cpue)) +
  geom_point() +
  geom_line() +
  geom_ribbon(aes(ymin = ll, ymax = ul), alpha=0.2) +
  ylab("CPUE (round lbs/pot)\n") +
  xlab('\nYear') +
  scale_x_continuous(breaks = xaxis$breaks, labels = xaxis$labels) +
  theme(plot.margin = unit(c(0.5,1,0.5,0.5), "cm")) +
  expand_limits(y = 0) 

ggsave("figures/pot_fishery_cpue.png", width = 6.5, 
       height = 5, units = "in", dpi = 200)

# ll survey cpue ----
# standardize hook spacing (Sigler & Lunsford 2001, CJFAS) changes in 
# hook spacing. pers. comm. with aaron.baldwin@alaska.gov: 1995 & 1996 -
# 118 in; 1997 - 72 in.; 1998 & 1999 - 64; 2000-present - 78". This is
# different from KVK's code (he assumed 3 m before 1997, 2 m in 1997 and
# after)
# soak time was standardized to at least 3 hours in 1997 prior to that it was 1 hour 
# Mike Vaughn 2018-03-06: Sets (aka subsets with 12 or more invalid hooks are subset condition code "02" or invalid)

hooks_df %>% 
  dplyr::select(year, subset_condition_code = `subset condition code`, 
                g_stat_area = `g stat area`, hooks_bare = `hooks - bare`,
                hooks_bait = `hooks - baited`, hooks_invalid = `hooks - invalid`,
                no_hooks = `hooks - total`, sablefish) %>% 
  filter(year >= 1998, 
         subset_condition_code %in% c(1, 3), 
         no_hooks != 0) %>% 
  mutate(Year = factor(year),
         Stat = factor(g_stat_area),
         hooks_bare = ifelse(is.na(hooks_bare), 0, hooks_bare),
         hooks_bait = ifelse(is.na(hooks_bait), 0, hooks_bait),
         hooks_invalid = ifelse(is.na(hooks_invalid), 0, hooks_invalid),
         no_hooks = no_hooks - hooks_invalid,
         std_hooks = ifelse(year %in% c(1998, 1999), 2.2 * no_hooks * (1 - exp(-0.57 * (64 * 0.0254))),
                            2.2 * no_hooks * (1 - exp(-0.57 * (78 * 0.0254)))),
         sablefish_retained = replace_na(sablefish, 0), 
         std_cpue = sablefish_retained / std_hooks) %>% 
  group_by(year) %>% 
  summarise(lcpue = mean(log(std_cpue + 1)),
            lsdev = sd(log(std_cpue + 1)),
            n = n()) %>% 
  mutate(cpue = exp(lcpue - 1),
         se = exp(lsdev - 1) / sqrt(n),
         ul = cpue + se * 2,
         ll = cpue - se * 2) %>% 
  ggplot(aes(year, cpue)) +
  geom_point() +
  geom_line() +
  geom_ribbon(aes(ymin = ll, ymax = ul), alpha = 0.2) +
  expand_limits(y = 0) +
  ylab('CPUE (fish/hook)\n') +
  xlab('\nYear') +
  scale_x_continuous(breaks = xaxis$breaks, labels = xaxis$labels) +
  theme(plot.margin = unit(c(0.5,1,0.5,0.5), "cm"))

ggsave("figures/ssei_ll_survey_cpue.png", width = 6.5, 
       height = 5, units = "in", dpi = 200)

# ll fishery cpue ----

ll_set_df %>% 
  select(year, trip_no, adfg = adfg_no, Spp_cde = trip_target, time_set,
         time_hauled, Gear = longline_system_code, hook_size,  
         hook_spacing, Stat = g_stat_area, no_hooks = number_of_hooks, 
         depth = average_depth_meters, 
         sets = effort_no, sable_lbs_set = sable_lbs_per_set, 
         start_lat = start_latitude_decimal_degrees,
         start_lon = start_longitude_decimal_degree) %>% 
  mutate(date = anydate(time_set),
         julian_day = yday(date),
         time_set = anytime(time_set),
         time_hauled = anytime(time_hauled),
         soak = difftime(time_hauled, time_set, units = 'hours'),
         Gear = factor(Gear),
         Gear = case_when(Gear == "06" ~ "AB",
                          Gear %in% c("01", "02", "05") ~ "CS",
                          TRUE ~ "Other"),
         Hook_size = factor(hook_size),
         Size = factor(as.numeric(gsub("[^0-9]", "", hook_size))),
         Year = factor(year),
         ADFG = factor(adfg),
         std_hooks = 2.2 * no_hooks * (1 - exp(-0.57 * (hook_spacing / 39.37))), 
         std_cpue = sable_lbs_set / std_hooks,
         dum = 1, 
         dumstat = 1) %>% 
  filter(!is.na(date), !is.na(hook_spacing), !is.na(sable_lbs_set),
         !is.na(start_lon), !is.na(start_lon), !is.na(soak), !is.na(depth),
         !is.na(hook_size), hook_size != "MIX", soak > 0) %>% 
  group_by(year, trip_no) %>% 
  mutate(no_sets = n_distinct(sets)) %>% 
  group_by(year) %>% 
  mutate(total_vessels = n_distinct(adfg),
         total_trips = n_distinct(trip_no)) %>% 
  ungroup() -> fishery_cpue 


fishery_cpue %>% 
  select(year, Vessels = total_vessels, Trips = total_trips) %>% 
  gather(Variable, Count, -year) %>% 
  distinct() %>%   
  ggplot(aes(year, Count)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  facet_wrap(~ Variable, ncol = 1, scales = "free") +
  labs(x = "\nYear", y = "") +
  scale_x_continuous(breaks = xaxis$breaks, labels = xaxis$labels) +
  expand_limits(y = 0) +
  theme(plot.margin = unit(c(0.5,1,0.5,0.5), "cm"))


ggsave("figures/fishery_trip_vessel_trends_1997_2018.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# nominal cpue ----
xaxis <- FNGr::tickr(fishery_cpue, year, 2)

fishery_cpue %>% 
  group_by(year) %>% 
  summarise(annual_cpue = mean(std_cpue),
            sdev = sd(std_cpue),
            se = sdev / sqrt(n()),
            var = var(std_cpue),
            cv = sdev / annual_cpue,
            upper = annual_cpue + (2 * se),
            lower = annual_cpue - (2 * se)) %>% 
  ggplot(aes(year, annual_cpue)) +
  geom_line() +
  geom_point() +
  geom_ribbon(aes(ymin = lower, ymax = upper),
              alpha = 0.3) +
  ylab("Standardized Longline Fishery CPUE (round lbs/hook)\n") +
  xlab("\nYear") +
  scale_x_continuous(breaks=xaxis$breaks, labels=xaxis$labels) +
  expand_limits(y = 0) +
  theme(plot.margin = unit(c(0.5,1,0.5,0.5), "cm"))

ggsave("figures/ssei_ll_fishery_cpue.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# ages ----

xaxis <- FNGr::tickr(svy_bio_df, year, 3) 

svy_bio_df %>% 
  filter(age != "NA", sex %in% c("Male", "Female"), 
         `age readability` %in% c("Very Sure", "Comfortably Sure", "Fairly Sure")) %>% 
  group_by(year, sex, age) %>% 
  count(age) %>% 
  ggplot(aes(year, age, size = n)) + 
  geom_point(shape = 21) + 
  scale_size_area() +
  facet_wrap(~sex, ncol = 1) + 
  ylab("Observed Age") + 
  theme(legend.position = "none") + 
  scale_x_continuous(breaks=xaxis$breaks, labels = xaxis$labels) + 
  scale_y_continuous(breaks = seq(0, 60, 10))

ggsave("figures/ll_survey_age.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# ages by gear type ----
# ll gear
fish_bio_df %>% 
  filter(project_code == 2, age != "NA", 
         sample_type == "Random", sex_code %in% c(1, 2), 
         age_readability_code %in% c(1, 2, 3)) %>% 
  mutate(Sex = case_when(sex_code == 1 ~ "Male",
                         sex_code == 2 ~ 'Female',
                         TRUE ~ 'Other')) %>%
  group_by(year, Sex, age) %>% 
  count(age) %>% 
  ggplot(aes(year, age)) + 
  geom_point(aes(size = n), shape = 21) +
  scale_size_area() + 
  facet_wrap(~Sex, ncol = 1) + 
  theme(legend.position = "none") + 
  ylab("Observed Age") + xlab("Year") +
  scale_x_continuous(breaks = xaxis$breaks, labels = xaxis$labels) + 
  scale_y_continuous(breaks = seq(0, 50, 10), limits = c(0, 50))

ggsave("figures/ll_fishery_age.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)


# pot gear

fish_bio_df %>% 
  filter(project_code == 17, age != "NA", 
         sample_type == "Random", sex_code %in% c(1, 2), 
         age_readability_code %in% c(1, 2, 3)) %>% 
  mutate(Sex = case_when(sex_code == 1 ~ "Male",
                         sex_code == 2 ~ 'Female',
                         TRUE ~ 'Other')) %>%
  group_by(year, Sex, age) %>% 
  count(age) %>% 
  ggplot(aes(year, age)) + 
  geom_point(aes(size = n), shape = 21) +
  scale_size_area() + 
  facet_wrap(~Sex, ncol = 1) + 
  theme(legend.position = "none") + 
  ylab("Observed Age") + xlab("Year") +
  scale_x_continuous(breaks = xaxis$breaks, labels = xaxis$labels) + 
  scale_y_continuous(breaks = seq(0, 50, 10), limits = c(0, 50))

ggsave("figures/pot_fishery_age.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)


# lengths ----

fish_bio_df %>% 
  filter(sex_code!=0) %>% 
  mutate(Sex = case_when(sex_code == 1 ~ "Male",
                         sex_code == 2 ~ 'Female',
                         TRUE ~ 'Other'),
         length = length_millimeters / 10,
         survey_type = ifelse(project_code==2, 'Longline', 'Pot'),
         Year = factor(year)) -> fish_lengths

fish_lengths %>% 
  ggplot(aes(length, Year, group = Year, fill = Year)) + 
  geom_density_ridges(aes(point_fill = Year, point_color = Year),
                      alpha = 0.3) +
  geom_vline(xintercept = 61, linetype = 4) +
  xlim(35, 90) + 
  xlab("\nLength (cm)") + 
  ylab("Year\n") +
  theme(legend.position = "none") + 
  facet_wrap(~ survey_type)

ggsave("figures/ssei_fishery_lengths.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# length by gear types ----
# longline
fish_lengths %>% 
  filter(survey_type == "Longline", Sex != 'Other') %>% 
  ggplot(aes(length, Year, group = Year, fill = Year)) + 
  geom_density_ridges(aes(point_fill = Year, point_color = Year),
                       scale = 3, alpha = 0.3) +
  geom_vline(xintercept = 61, linetype = 3) +
  xlim(35, 90) +
  xlab("\nLength (cm)") + 
  ylab("Year\n") +
  facet_wrap(~ Sex)

ggsave("figures/ssei_fishery_ll_lengths.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# pot
fish_lengths %>% 
  filter(survey_type == "Pot", Sex != 'Other') %>% 
  ggplot(aes(length, Year, group = Year, fill = Year)) + 
  geom_density_ridges(aes(point_fill = Year, point_color = Year),
                      scale = 3, alpha = 0.3) +
  geom_vline(xintercept = 61, linetype = 3) +
  xlim(35, 90) +
  xlab("\nLength (cm)") + 
  ylab("Year\n") +
  theme(legend.position = "none") +
  facet_wrap(~ Sex)

ggsave("figures/ssei_fishery_pot_lengths.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)

# survey lengths ----
svy_bio_df %>% 
  filter(sex %in% c('Male', 'Female')) %>% 
  mutate(length = `length millimeters` / 10, 
         Year = factor(year)) %>% 
  ggplot(aes(length, Year, group = Year, fill = Year)) + 
    geom_density_ridges(aes(point_fill = Year, point_color = Year),
                        scale = 3, alpha = 0.3) +
    geom_vline(xintercept = 61, linetype = 3) +
    xlab("Length (cm)") + ylab("Year") +
  theme(legend.position = "none") +
  xlim(35, 90) +
  facet_wrap(~ sex)

ggsave("figures/ssei_survey_lengths.png", width = 6.5, 
       height = 8, units = "in", dpi = 200)
