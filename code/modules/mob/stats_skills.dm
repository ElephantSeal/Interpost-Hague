//////////////////////////////////////////////////////////////////////////
//This is the file where all the stats and skills procs are kept.	    //
//The system is kinda barebones now but I hope to rewrite it to  	    //
//be betting in the near future. 								 	    //
//																 	    //
//Stats are pretty generic, skills are kind of specific. 				//
//You should just be able to plop in the proc call wherever you want.   //
//I tried to make it versitile.											//
// - Matt 																//
//////////////////////////////////////////////////////////////////////////

//defines
#define CRIT_SUCCESS_NORM 1
#define CRIT_FAILURE_NORM 1
#define CRIT_SUCCESS 2
#define CRIT_FAILURE 3



//I am aware this is probably the worst possible way of doing it but I'm using this method till I get a better one. - Matt
/mob
	var/list/stats = list(str = 10, dex = 10, int = 10, con = 10)
	var/list/skills = list("melee" = 0, "ranged" = 0, "medical" = 0, "surgery" = 0, "engineering" = 0, "crafting" = 0, "cooking" = 0, "science" = 0, "cleaning" = 0, "gardening" = 0, "mining" = 0)

/*    ===== STATS ====
	Stats are the base of your characer.  They are generated by rolling 3 rand(1,6) and adding the total for each stat. Between (3-18)
	Each jobs has it's own "main stat" wich the highest value generated is assigned to.  The rest are random.

		These stats are going to be more varried then old interbay, but I think that's ok, as it gives you weakenesses to exploit.  All arbiters
	may be strong, but they may be slow or frail.

	Checks are performed by rolling rand(1,20) then adding (stat - 10) * 0.5  (18 = +4, 16 = +3, 14 = +2, 12 = +1, 10 = 0, 8 = -1, 6 = -2, 4 = -3)
	Each check sets it's own difficulty (DC), which the roll + stat mod + mood mod are added too

	Stat checks should mainly be used for things happening to the player.  Are you strong enough to open the airlock?  Are you dexterious enough
	to dodge this attack?  Some old checks may break this rule, but try to stick to it.

	The new stats check will certainly be more random then the old stats check, as exceeding the difficulty (DC) of the check won't be an automatic pass.
	This will need to be tweaked and tested. the old stats check is commented at the bottom.
*/

// Takes a stat *VALUE*.
/mob/proc/statcheck(var/stat, var/requirement, var/message = null, var/type = null)//Requirement needs to be 1 through 20
	var/roll = rand(1,20)// our "dice"
	//log_debug("Roll: [roll], Mood affect: (-)[mood_affect(1)], Ability modifier [stat_to_modifier(stat)]")
	log_debug("[src] Rolled a [roll] against a DC [requirement] [type] check")
	roll -= mood_affect(1)// our mood
	roll += stat_to_modifier(stat) //our stat mod
	learn_stats(type)
	if(roll >= requirement)//We met the DC requirement
		//world << "Rolled and passed."
		return 1
	else
		if(message)
			to_chat(src, "<span class = 'warning'>[message]</span>")
		return 0
	return 1

/mob/proc/learn_stats(var/stat_type)
	var/initial_stat = round(stats[stat_type])
	if(stat_to_modifier(stats["int"]) > 0)
		stats[stat_type] += 0.01 * stat_to_modifier(stats["int"])
	else 
		if(stats[stat_type] < 20)
			stats[stat_type] += 0.01
		else //Learn slower past 20
			if(stats[stat_type] >= 40)
				return 0 //cant learn above 40
			else
				stats[stat_type] += 0.01
	if(round(stats[stat_type]) > initial_stat)
		to_chat(src,"You feel like live you've gained new insights.")

//having a bad mood fucks your shit up fam.
/mob/proc/mood_affect(var/stat, var/skill)
	//Just check this first
	if(!iscarbon(src))
		return 0
	var/mob/living/carbon/C = src
	// We return the mood, based on MOOD_LEVEL_NEUTRAL or whatever
	if(stat)
		return C.happiness * -0.2 /* 1/5th of our happiness This will be SUBTRACTED from the stat roll.  Goes from +4 to -4 */
	if(skill)
		return C.happiness //This will be ADDED to the skill roll.  Goes from +20 - -20  *PENDING REWORK&*
	return 0

proc/stat_to_modifier(var/stat)
	return round((stat - 10) * 0.5)

proc/strToDamageModifier(var/strength)
	return strength * 0.1  //This is better then division

proc/strToSpeedModifier(var/strength, var/w_class)//Looks messy. Is messy. Is also only used once. But I don't give a fuuuuuuuuck.
	switch(strength)
		if(1 to 5)
			if(w_class > ITEM_SIZE_NORMAL)
				return 20

proc/conToToxinModifier(var/constitution, var/w_class)
	return stat_to_modifier(constitution) * 0.05

//Stats helpers.
/mob/proc/add_stats(var/stre, var/dexe, var/inti, var/cons)//To make adding stats quicker.
	if(stre)
		stats["str"] = stre
	if(dexe)
		stats["dex"] = dexe
	if(inti)
		stats["int"] = inti
	if(cons)
		stats["con"] = cons

//Different way of generating stats.  Takes a "main_stat" argument.
// Totals top 3 D6 for stats.  Then puts the top stat in the "main_stat" and the rest randomly
/mob/proc/generate_stats(var/main_stat)
	var/list/rand_stats = list()
	var/top_stat = 0
	//Roll a new random roll for each stat
	for(var/stat in stats)
		rand_stats += (rand(1,6) + rand(1,6) + rand(1,6))
	rand_stats = insertion_sort_numeric_list_descending(rand_stats)
	top_stat = rand_stats[1]
	rand_stats.Remove(top_stat)
	//Set the job's main stat
	stats[main_stat] = top_stat
	//Do all stat except main stat
	for(var/stat in stats - main_stat)
		stats[stat] = pick(rand_stats)
		rand_stats.Remove(stats[stat])

/mob/proc/adjustStrength(var/num)
	stats["str"] += num

/mob/proc/adjustDexterity(var/num)
	stats["dex"] += num

/mob/proc/adjustInteligence(var/num)
	stats["int"] += num


/mob/proc/temporary_stat_adjust(var/stat, var/modifier, var/time)
	if(stats[stat] && modifier && time)//In case you somehow call this without using all three vars.
		stats[stat] += modifier
		spawn(time)
			stats[stat] -= modifier

/*    ===== skills =====
	Skils work a lot differently then stats.  They have a hard limit that once you exceed it, you automatically pass.
	Otherwise, we run proc(skill) to see if you pass or not.
	I like this, because specific jobs can be given a garunteed chance to perform an action, while other will have to flouder through rng.

	Generated similarly to stats, just on a larger scale.  3 rand(1,34) are rolled, and totaled for each skill.  Main Skill(s) is set the higest
	rest are picked at random.

	There should be mainly used for specific actions by the player.  Are you skilled enough to construct this wall?  Are you skilled enough to
	bandage this patient?  I think this rule is adhered to mostly already in the doe.
*/
/mob
	//This is getting long fuuuucckk

	//crit shit
	var/crit_success_chance = CRIT_SUCCESS_NORM
	var/crit_failure_chance = CRIT_FAILURE_NORM
	var/crit_success_modifier = 0
	var/crit_failure_modifier = 0
	var/crit_mood_modifier = 0

/mob/proc/get_success_chance()
	return crit_success_chance + crit_success_modifier + crit_mood_modifier

/mob/proc/get_failure_chance()
	return crit_failure_chance + crit_failure_modifier + crit_mood_modifier


/mob/proc/skillcheck(var/skill, var/requirement, var/message = null, var/skill_type = null)//1 - 100
	log_debug("[skill_type] check!  Skill value: [skill], DC [requirement] source: [src]") //Debuging
	learn_skills(skill_type)
	if(skill >= requirement)//If we already surpass the skill requirements no need to roll.
		if(prob(get_success_chance()))//Only thing we roll for is a crit success.
			return CRIT_SUCCESS
		return 1
	else
		if(prob(skill + src.mood_affect(0, 1)))//Otherwise we roll to see if we pass.
			if(prob(get_success_chance()))//And again to see if we get a crit scucess.
				return CRIT_SUCCESS
			return 1
		else
			if(message)//If we don't have a message, just return failure
				to_chat(src, "<span class = 'warning'>[message]</span>")
			if(prob(get_failure_chance()))//And roll for a crit failure.
				return CRIT_FAILURE
			return 0

/mob/proc/learn_skills(var/skill_type)
	var/initial_skill = round(skills[skill_type])
	if(stat_to_modifier(stats["int"]) > 0) // This is still based off int
		skills[skill_type] += 0.01 * stat_to_modifier(stats["int"])
	else 
		if(stats[stat_type] < 20)
			stats[stat_type] += 0.01
		else //Learn slower past 20
			if(stats[stat_type] >= 40)
				return 0 //cant learn above 40
			else
				stats[stat_type] += 0.001
	if(round(skills[skill_type]) > initial_skill)
		to_chat(src,"You feel like live you've gained new insights.")

//Skill helpers.
/mob/proc/skillnumtodesc(var/skill)
	switch(skill)
		if(0 to 24)
			return "<small><i>unskilled</i></small>"
		if(25 to 44)
			return "alright"
		if(45 to 59)
			return "skilled"
		if(60 to 79)
			return "professional"
		if(80 to INFINITY)
			return "<b>godlike</b>"

// 3 rand(1,34) are rolled, and totaled for each skill.  Main Skill is set the higest, rest are picked at random.
/mob/proc/generate_skills(var/list/generate_skills)
	var/list/rand_skills = skills.Copy()
	//Roll a new random roll for each stat
	for(var/skill in generate_skills)
		skills[skill] = (rand(1,50) + rand(1,50) + rand(1,50))
		rand_skills -= skill
	for(var/skill in rand_skills)
		skills[skill] = (rand(1,15) + rand(1,15) + rand(1,15))
/*
/mob/proc/add_skills(var/melee_val, var/ranged_val, var/medical_val, var/engineering_val)//To make adding skills quicker.
	if(melee_val)
		melee = melee_val
	if(ranged_val)
		ranged = ranged_val
	if(medical_val)
		medical = medical_val
	if(engineering_val)
		engineering = engineering_val
*/
/mob/living/carbon/human/verb/check_skills()//Debug tool for checking skills until I add the icon for it to the HUD.
	set name = "Check Skills"
	set category = "IC"

	var/message = "<big><b>Skills:</b></big>\n"
	for(var/skill in skills)
		if(skills[skill] > 0)
			message += "I am <b>[skillnumtodesc(skills[skill])]</b> at [skill].\n"
	to_chat(src, message)

/* LEGACY STAT CODE
/mob/proc/statcheck(var/stat, var/requirement, var/show_message, var/message = "I have failed to do this.")//Requirement needs to be 1 through 20
	if(stat < requirement)
		var/H = rand(1,20)// our "dice"
		H += mood_affect(1)// our skill modifier
		if(stat >= H)//Rolling that d20
			//world << "Rolled and passed."
			return 1
		else
			if(show_message)//If we fail then print this message and return 0.
				to_chat(src, "<span class = 'warning'>[message]</span>")
			return 0
	else
		//world << "Didn't roll and passed."
		return 1
*/
