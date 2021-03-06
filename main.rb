require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'love_cookies'



BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do 
  def calculate_total(cards) 
    score = 0
    valid_card = cards.flatten.select {|card| card.length < 3}
    valid_card.each do |card|
      case 
      when card.to_i != 0 then score += card.to_i
      when card.to_i == 0 && card != "A" then score += 10 
      when card == "A" && score <= 10 then score += 11
      when card == "A" && score > 10 then score += 1
      when card == "A" && score > 21 then score += 1
      end
    end
    score
  end

  def display_card(card)
    suit = card[0]

    rank = card[1]
    if ['J', 'Q', 'K', 'A'].include?(rank)
      rank = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end      
    end
    
    "<img src='/images/cards/#{suit.downcase}_#{rank}.jpg' class='display_card' />"
  end

  def winner!(msg)
    session[:player_pot] += session[:player_bet]
    @play_again = true
    @winner = "<strong>#{session[:player_name]} has a total of #{calculate_total(session[:player_cards])} and the dealer has #{calculate_total(session[:dealer_cards])}. #{msg}</strong>"
    @show_hit_or_stay_buttons = false
  end

  def loser!(msg)
    session[:player_pot] -= (session[:player_bet])
    @play_again = true
    @loser = "<strong>#{session[:player_name]} has a total of #{calculate_total(session[:player_cards])} and the dealer has #{calculate_total(session[:dealer_cards])}. #{msg}</strong>"
    @show_hit_or_stay_buttons = false
  end

  def tie!(msg)
    @play_again = true
    @winner = "Both have a total of #{calculate_total(session[:dealer_cards])}! #{msg}"
    @show_hit_or_stay_buttons = false
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_pot] = INITIAL_POT_AMOUNT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = 'You must enter your name!'
    halt erb(:new_player)
  end
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
  if session[:player_pot] <= 0 
    @error = "Sorry looks like you have no money anymore! Please, start over!"
    halt erb(:bet)
  else
    erb :bet
  end
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0 
    @error = "You must make a bet!!"
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "You can't bet more than what you have!! #{session[:player_pot]}"
    halt erb(:bet)
  elsif params[:bet_amount].to_i < 0
    @error = "You can't bet a negative number!!!"
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]

  suits = ['Hearts', 'Diamonds', 'Spades', 'Clubs']
  values = ['2','3','4','5','6','7','8','9','10','J','Q','K','A']
  session[:deck] = suits.product(values).shuffle!

  session[:player_cards] = []
  session[:dealer_cards] = []
  2.times do
    session[:player_cards] << session[:deck].pop
    session[:dealer_cards] << session[:deck].pop
  end
  
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
    loser!("Sorry, dealer hit blackJack. #{session[:player_name]} loose!")
  end

  if player_total == BLACKJACK_AMOUNT
    winner!("Congratulations, #{session[:player_name]} hit blackJack!!!")
  end

  erb :game
end

post '/game/player/hit' do 
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])

  if player_total == BLACKJACK_AMOUNT
    winner!("Congratulations, #{session[:player_name]} hit blackJack!!!")
  elsif player_total > BLACKJACK_AMOUNT
    loser!("Sorry, #{session[:player_name]} busted!!!")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  redirect '/game/dealer'
end

get '/game/dealer' do
  @show_hit_or_stay_buttons = false 
  session[:turn] = 'Dealer'
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total > BLACKJACK_AMOUNT 
    winner!("Congratulations, #{session[:player_name]} wins!!")
  elsif dealer_total == BLACKJACK_AMOUNT
    loser!("Sorry, dealer hit blackJack. #{session[:player_name]} loose!")
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/game/compare'
  else
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("Sorry, Dealer win!!")
  elsif player_total > dealer_total
    winner!("Congratulations, Dealer Busted!!")
  else
    winner!("This is a Tie!!")
  end

  erb :game, layout: false   
end

get '/game_over' do 
  erb :game_over
end












