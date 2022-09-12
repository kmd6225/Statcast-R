library(baseballr)
library(ggplot2)
library("gridExtra") 
library(car)
library(dplyr)
library(fastDummies)
library(lubridate)
#-------------------------------------Import Data--------------------------------------
#scrape all pitches thrown by Gerrit Cole for the 2022 season so far

#vector of dates for scraping

date1 <- c('2022-04-07','2022-04-14','2022-04-28', '2022-05-05','2022-05-12','2022-05-19', '2022-05-24',
           '2022-05-31', '2022-6-07', '2022-06-14', '2022-06-21', '2022-06-28', '2022-07-05', 
           '2022-07-12', '2022-07-19', '2022-07-26', '2022-08-03', '2022-08-10', '2022-08-17',
           '2022-08-24', '2022-08-31')

date2 <- c('2022-04-14','2022-04-28', '2022-05-05','2022-05-12','2022-05-19', '2022-05-24',
           '2022-05-31', '2022-6-07', '2022-06-14', '2022-06-21', '2022-06-28', '2022-07-05', 
           '2022-07-12', '2022-07-19', '2022-07-26', '2022-08-03', '2022-08-10', '2022-08-17',
           '2022-08-24', '2022-08-31', '2022-09-07')

#initialize empty dataframe to store cole data

cole <- data.frame()

#loop through each week of the season and scrape the pitches thrown by cole

for (i in 1:length(date1)){
    tempdf <- scrape_statcast_savant_pitcher(date1[i],date2[i], 543037)
    cole <- rbind(cole, tempdf)
}


#----------------------------------------Data Cleaning and EDA--------------------------

is_hit <- c()

for (i in 1:length(cole$events)){
    
    if (cole$events[i] == 'single' | cole$events[i] == 'double' | cole$events[i] == 'triple' | 
        cole$events[i] == 'home run'){
        is_hit[i] <- 1
    } else { is_hit[i] <- 0 }}


cole$is_hit <- is_hit

cole$count <- cole$balls + cole$strikes


#FIPS Analysis

fip_constant <- 3.10

cole <- dummy_cols(cole, select_columns = 'events')

daily_stats <- cole %>% group_by(game_date) %>% summarise('HR' = sum(events_home_run), 'BB'= sum(events_walk), 'HBP' = sum(events_hit_by_pitch), 
                                                          'K' = sum(events_strikeout), 'IP' = sum(length(unique(inning))))

FIP = function(df){
    FIP = (13 * df$HR + 3 *(df$BB + df$HBP) - 2* df$K)/df$IP + fip_constant
    return(FIP)
}

fip_vec <- c()

for (i in 1:nrow(daily_stats)){
    df <- daily_stats[i,]
    fip_vec <- c(fip_vec, FIP(df))
}

daily_stats$fip <- fip_vec

daily_stats$month <- month(daily_stats$game_date)


monthly_stats <- daily_stats %>% group_by(month) %>% summarise('Avg_FIP' = mean(fip))

ggplot(daily_stats, aes(x = game_date,
                          y = fip
)) + geom_line( color = 'Red') +  ggtitle('Gerrit Cole Daily FIP') +  ylab('FIP') + xlab('Date') + theme(plot.title = element_text(hjust = 0.5))



#Strikeout Percentage


K_percent <- cole %>% group_by(inning) %>% summarise('K' = sum(events_strikeout), 'Pitches' = n())
K_percent$strikeout_pct <- round(K_percent$K/K_percent$Pitches * 100,2)

K_percent <- K_percent[1:nrow(K_percent) -1,]

ggplot(K_percent, aes(x = inning, y = strikeout_pct)) + geom_bar( fill = 'dark red', stat = 'identity') + ggtitle('Gerrit Cole %K By Inning') + xlab('Inning') + ylab('Strikout Percentage') + theme(plot.title = element_text(hjust = 0.5))




K_percent_pitch <- cole %>% group_by(pitch_name) %>% summarise('K' = sum(events_strikeout), 'Pitches' = n())
K_percent_pitch$strikeout_pct <- round(K_percent_pitch$K/K_percent_pitch$Pitches * 100,2)


ggplot(K_percent_pitch, aes(x = pitch_name, y = strikeout_pct)) + geom_bar( fill = 'dark red', stat = 'identity') + ggtitle('Gerrit Cole %K By Pitch Type') + xlab('Pitch Type') + ylab('Strikout Percentage') + theme(plot.title = element_text(hjust = 0.5))



#Fastball analysis


game_ids <- unique(cole$game_pk)

total_pitch_vec <- c()

j = 0
id_check = 661313
for (i in 1:nrow(cole)){
    if (cole$game_pk[i] == id_check){
        j = j + 1
        total_pitch_vec <- c(total_pitch_vec, j)
        
    } else{
        id_check = cole$game_pk[i]
        j = 1
        total_pitch_vec <- c(total_pitch_vec, j)}
}

cole$total_game_pitch <- total_pitch_vec

Fastball <- cole[cole$pitch_name == '4-Seam Fastball',]

fastball_avg <- Fastball %>% group_by(total_game_pitch) %>% summarise('average_release_speed' = mean(release_speed))

ggplot(fastball_avg, aes(x = total_game_pitch, y = average_release_speed)) + geom_point(color = 'dark gray') + geom_smooth(method = 'lm', color = 'dark red') + ggtitle('Gerrit Cole Average Fastball Velocity vs Total Pitches') + xlab('Total Pitches') + ylab('Average Fastball Velocity') + theme(plot.title = element_text(hjust = 0.5))

#Create a dataframe representing the strike zone coordinates

x <- c(-.95,.95,.95,-.95,-.95)
z <- c(1.6,1.6,3.5,3.5,1.6)

#store in dataframe
sz <- data.frame(x,z)

#Get Strikes thrown by Cole

cole_strike <- cole[cole$description == 'called_strike' | cole$description == 'swinging_strike',]

#Get non-strikes thrown by Cole

cole_non_strikes <- cole[cole$description == 'hit_into_play',]

ggplot()+
    geom_path(data = sz, aes(x=x, y=z))+
    coord_equal()+
    xlab("feet from home plate")+
    ylab("feet above the ground")+
    geom_point(data = cole_strike,aes(x=plate_x,y=plate_z,size=release_speed, color = pitch_name))+
    scale_size(range = c(0.01,3)) + ggtitle('Gerrit Cole Strikes') + theme(plot.title = element_text(hjust = 0.5))

ggplot()+
    geom_path(data = sz, aes(x=x, y=z))+
    coord_equal()+
    xlab("feet from home plate")+
    ylab("feet above the ground")+
    geom_point(data = cole_non_strikes,aes(x=plate_x,y=plate_z,size=release_speed, color = pitch_name))+
    scale_size(range = c(0.01,3)) + ggtitle('Gerrit Cole Pitches Hit Into Play') + theme(plot.title = element_text(hjust = 0.5))




pitches_by_innings <- cole %>% group_by(inning, pitch_name) %>% summarise('Count_of_pitch_type' = n())


pct_vec  <- c()
for (i in 1:nrow(pitches_by_innings)){
    inning_sum <- sum(pitches_by_innings$Count_of_pitch_type[pitches_by_innings$inning == pitches_by_innings$inning[i]])
    pct_vec <- c(pct_vec, round(pitches_by_innings$Count_of_pitch_type[i]/inning_sum * 100,2))
}


pitches_by_innings$pct_of_total <- pct_vec

pitches_by_innings <- pitches_by_innings[pitches_by_innings$inning != 8,]

ggplot(pitches_by_innings, aes(fill=pitch_name, y=pct_of_total, x=inning)) + 
    geom_bar(position="dodge", stat="identity") + ggtitle('Gerrit Cole Pitch Percent of Total By Inning') + xlab('Inning') + ylab('Percent of Total') + theme(plot.title = element_text(hjust = 0.5))

