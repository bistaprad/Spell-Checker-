require 'csv'

class SpellCheck
	attr_reader :typed_name, :count_ed1, :count_ed2, :ed1, :ed2, :weight_ed1, :weight_ed2
	attr_reader :working_dictionary, :suggestion, :ed1_tot_freq, :ed2_tot_freq, :total_freq, :year
  @@LETTERS
  @@dictionary
  
  def initialize()
    @@dictionary = Hash.new(Hash.new)
    @working_dictionary = Hash.new
    @ed1_tot_freq = 0.0
    @ed2_tot_freq = 0.0
    @total_freq = 0.0
    @count_ed1 = 0
    @count_ed2 = 0
    @weight_ed1 = 1
    @weight_ed2 = 0.1
    @suggestion = []
    @@LETTERS = ("a".."z").to_a.join
    
    bulk_import # import name & freq from all files
    create_csv  # create a CSV file with title only
  end

  # Add which year is inserted in the @working_dictionary
  def add_year year
    @year = year
  end

  #To import all the CSV files from a directory
  def bulk_import 
    location = "./US_birth_name_frequencies/"
    dir_contents = Dir.entries(location)
    dir_contents = dir_contents.sort!
    dir_contents = dir_contents[2..dir_contents.length-1]
    dir_contents.each do |file_name|
    add_to_dictionary(location,file_name)
    end
  end

  def add_to_dictionary(location, file_name)
    year = file_name.split(".")
    year = (year[0][3..year[0].length-1])
    dict_by_year = add_file_to_dictionary(File.new(location+file_name).read)
    @@dictionary[year.to_i] = dict_by_year
  end

  def add_file_to_dictionary(features)
    dict_by_year = Hash.new{}
    total_freq = 0
    #count total frequency
    features.each_line do |line|
      splits = line.split(",")
      total_freq += Integer(splits[2])
    end
    features.each_line do |line|
      splits = line.split(",")
      # Remove the dublicate entry of name and add the frequency while building the HASH
      if dict_by_year.has_key?(splits[0].downcase)  
        dict_by_year[splits[0].downcase] = ( (Integer(splits[2]) + (dict_by_year[splits[0].downcase]*total_freq) ) / Float(total_freq))
      else
        dict_by_year[splits[0].downcase] = ( Integer(splits[2])/Float(total_freq))
       end
      # if dict_by_year.has_key?(splits[0].downcase)  
      #   dict_by_year[splits[0].downcase] = Math.log10( (Integer(splits[2]) + (dict_by_year[splits[0].downcase]) ) )
      # else
      #   dict_by_year[splits[0].downcase] = Math.log10( Integer(splits[2])) 
      # end
    end
    return dict_by_year
  end

  #Add the name and frequency by year to the working_dictionary
  def add_year_to_dictionary(year)
    @working_dictionary = @@dictionary[year]
  end

  def edits1 word
    n = word.length
    deletion = (0...n).collect {|i| word[0...i]+word[i+1..-1] }
    transposition = (0...n-1).collect {|i| word[0...i]+word[i+1,1]+word[i,1]+word[i+2..-1] }
    alteration = []
    n.times {|i| @@LETTERS.each_byte {|l| alteration << word[0...i]+l.chr+word[i+1..-1] } }
    insertion = []
    (n+1).times {|i| @@LETTERS.each_byte {|l| insertion << word[0...i]+l.chr+word[i..-1] } }
    result = deletion + transposition + alteration + insertion
    
  end

  def known_edits2 word
    result = []
    edits1(word).each {|e1| 
      edits1(e1).each {|e2| 
        result << e2 if working_dictionary.has_key?(e2) 
      }
    }
    result
    # result.empty? ? nil : result
  end

  def known words
    result = words.find_all {|w| working_dictionary.has_key?(w) }
    result
    # result.empty? ? nil : result
  end

  #Finds the top five suggestion from edit distance one and two,
  #accoring to their scores.
  def select_top_five
    ed1_ed2_merged = @ed1.merge(@ed2)
    top5_words = ed1_ed2_merged.sort_by{|k,v| -v}.first 5
    top5_words = Hash[*top5_words.flatten]
    final_list = Hash.new{}
    # If the typed_word isnt in the dictionary, replace 5th suggestion by typed_word 
    if !working_dictionary.has_key?( @typed_name )
        top5_words.each_with_index { |(k,v),index|
          if index == (top5_words.length-1)
            final_list[@typed_name] = v*0.5
          else
            final_list[k] = v
          end
        }
        top5_words = final_list
    end
    @suggestion = top5_words
    return top5_words       #Hash of words and corresponding score 
  end

  # Calculates the socre for each edit distance's suggestion list
  def calc_score(word_list, total_freq, weight)
    hash = Hash.new{}
    word_list.each{|w|
      s = (weight * working_dictionary[w]/(total_freq)*100).round(4)
      hash[w] = s   
    }
    hash = hash.sort_by{|k,v| -v} 
    hash = Hash[*hash.flatten]
    return hash
  end

  def sort_top_n_words_by_frequency(words, n)
    sorted_words = words.sort_by{|w| -working_dictionary[w] }
    array = sorted_words.first n
    return array
  end

  def correct
    # Get list non-repeated words with edit distances ONE
    @ed1 = (known(edits1( @typed_name ))).uniq
    @count_ed1 = @ed1.length

    # Get list non-repeated words with edit distances TWO
    @ed2 = (known_edits2( @typed_name )).uniq
    @count_ed2 = @ed2.length

    # Ignore words with @ed2 for the word length of THREE
    if( @typed_name.length<= 3)
      @ed2 = []
    end

    # Sort the words in list accoring to frequency and grab only top 10 words
    @ed1 =sort_top_n_words_by_frequency(@ed1,10)
    @ed2 = sort_top_n_words_by_frequency(@ed2,10)

    # Remove the words from @ed2 which already appeared @ed1
    edit2 = []
      @ed2.each do |w|
        if !@ed1.include?(w) 
          edit2.push(w) 
        end   
      end

    @ed2 = edit2

    # Calculate total frequency for @ed1 array
    @ed1.each do |w|
      @ed1_tot_freq += working_dictionary[w]
    end

    # Calculate total frequency for @ed2 array
    @ed2.each do |w|
      @ed2_tot_freq += working_dictionary[w]
    end

    # total frequency of @ed1 & @ed2
    @total_freq = @ed1_tot_freq + @ed2_tot_freq

    if @count_ed1 > @count_ed2
      weight  = Float(1)/@count_ed1
    else 
      weight = Float(1)/@count_ed2
    end

    # Calculate score for each words in @ed1
    @ed1 = calc_score(@ed1, @ed1_tot_freq , weight) 

    # Calculate score for each words in @ed1
    @ed2 = calc_score(@ed2, @ed2_tot_freq , weight*0.1)

    # Select top five suggestions from @ed1 & @ed1 
    select_top_five
  end  

  # Create CSV file with title only
  def create_csv
    title = ["Typed Word","Suggestion", "Score", "Frequency", "ED?", "Count ED", "Year"]
    CSV.open('output.csv', 'a') do |csv|
      csv << title
    end
  end

  # Append a line in CSV file ||Typed Name||Suggestion||Score||Frequency||ED||Count ED||
  def export_csv
    correct
    CSV.open('output.csv', 'a') do |csv|
      @suggestion.each_with_index{|(name,score), index|
        word =  @typed_name.capitalize                  #typed name
        sugges = name.capitalize                        #suggestion name
        score = (@suggestion[name].round(3)).to_s       #score of this suggestion
        years = @year                                   #which years are inserted to dictionary
        ed = "NA"                                       #which ED this name belongs to
        ed_count = "NA"                                 #how many candidates fall in ED of this name

        # Check frequency for the words in suggestion list
        # Typed word, not in the dictionary has zero frequency
        if @working_dictionary.has_key?(name)
          freq = (@working_dictionary[name]).to_s  
        else
          freq = 0
        end
        
        # Check which edit distance the word belongs to.

        # Check if the word is from @ed1
        if !@ed1.empty?
          if @ed1.include?(name)
            ed = 1.to_s
            ed_count = @count_ed1.to_s
          end
        end

        # Check if the word is from @ed2
        if !@ed2.empty?
          if @ed2.include?(name)
            ed = 2.to_s
            ed_count = @count_ed2.to_s
          end  
        end

        # Build a string to insert in csv file
        if index == 0    # years are displayed only in first line for this @typed_name
          line = [word, sugges, score, freq, ed, ed_count, year]  
        else
          line = [word, sugges, score, freq, ed, ed_count]  
        end

        csv << line
      }
      csv << []  # insert blank line as last line
    end
  end

  def suggest_name(name, year)

    @typed_name = name.downcase
    @year = year                        #set the year 
    add_year_to_dictionary(year)        #create a dictionary of given year
    export_csv
    
  end

end

# #List of test typed names
test_case = ['Dalila','Haelen','Haabel','Marrk','Maccy','Hlen','Egenia','acy',
             'Dcire','Hleen','Mable','Dicei','Hilin','Mabal','Maoy','Dlcie',
             'Dark','Rogert','Decei','roth','rosa','evan','jelma','alv', 'rose']

spellcheck =SpellCheck.new()

test_case.each do |w|
  spellcheck.suggest_name(w, 1881)
end

 





