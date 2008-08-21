module Enumerable
  def histogram
	  histogram = inject(Hash.new(0)) { |hash, x| hash[x] += 1; hash}
  end
  
  def sort_by_frequency
    histogram = inject(Hash.new(0)) { |hash, x| hash[x] += 1; hash}
    sort_by { |x| [histogram[x], x] }
  end
  
  def values_with_multiple_instances(instances = 2)
    select{|x| histogram[x] >= instances}.uniq
  end
  
  # use when you have a collection of objects and you want to see if one of the values
  # on those objects occurs multiple times
  def method_values_with_multiple_instances(method_name, instances = 2)
    duplicate_values = collect{|x| x.send(method_name)}.values_with_multiple_instances(instances)
    select{|x| duplicate_values.include? x.send(method_name)}
  end
end