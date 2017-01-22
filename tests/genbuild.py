#!/usr/bin/env python3

"""
Generates a synthetic build description.

The tasks simply copy their inputs to outputs. Tasks are chained together in
random ways.

The primary purpose of this script is to fuzz test the build system. We aren't
expecting everything to succeed. We just want to know if it crashes.
"""

import os
import json
import string
import argparse
import itertools

from random import Random

from pprint import pprint

# Top 500 adjectives
adjectives = [
    'different', 'used', 'important', 'every', 'large', 'available', 'popular',
    'able', 'basic', 'known', 'various', 'difficult', 'several', 'united',
    'historical', 'hot', 'useful', 'mental', 'scared', 'additional',
    'emotional', 'old', 'political', 'similar', 'healthy', 'financial',
    'medical', 'traditional', 'federal', 'entire', 'strong', 'actual',
    'significant', 'successful', 'electrical', 'expensive', 'pregnant',
    'intelligent', 'interesting', 'poor', 'happy', 'responsible', 'cute',
    'helpful', 'recent', 'willing', 'nice', 'wonderful', 'impossible',
    'serious', 'huge', 'rare', 'technical', 'typical', 'competitive',
    'critical', 'electronic', 'immediate', 'aware', 'educational',
    'environmental', 'global', 'legal', 'relevant', 'accurate', 'capable',
    'dangerous', 'dramatic', 'efficient', 'powerful', 'foreign', 'hungry',
    'practical', 'psychological', 'severe', 'suitable', 'numerous',
    'sufficient', 'unusual', 'consistent', 'cultural', 'existing', 'famous',
    'pure', 'afraid', 'obvious', 'careful', 'latter', 'unhappy', 'acceptable',
    'aggressive', 'boring', 'distinct', 'eastern', 'logical', 'reasonable',
    'strict', 'administrative', 'automatic', 'civil', 'former', 'massive',
    'southern', 'unfair', 'visible', 'alive', 'angry', 'desperate', 'exciting',
    'friendly', 'lucky', 'realistic', 'sorry', 'ugly', 'unlikely', 'anxious',
    'comprehensive', 'curious', 'impressive', 'informal', 'inner', 'pleasant',
    'sexual', 'sudden', 'terrible', 'unable', 'weak', 'wooden', 'asleep',
    'confident', 'conscious', 'decent', 'embarrassed', 'guilty', 'lonely',
    'mad', 'nervous', 'odd', 'remarkable', 'substantial', 'suspicious', 'tall',
    'tiny', 'more', 'some', 'one', 'all', 'many', 'most', 'other', 'such',
    'even', 'new', 'just', 'good', 'any', 'each', 'much', 'own', 'great',
    'another', 'same', 'few', 'free', 'right', 'still', 'best', 'public',
    'human', 'both', 'local', 'sure', 'better', 'general', 'specific', 'enough',
    'long', 'small', 'less', 'high', 'certain', 'little', 'common', 'next',
    'simple', 'hard', 'past', 'big', 'possible', 'particular', 'real', 'major',
    'personal', 'current', 'left', 'national', 'least', 'natural', 'physical',
    'short', 'last', 'single', 'individual', 'main', 'potential',
    'professional', 'international', 'lower', 'open', 'according',
    'alternative', 'special', 'working', 'true', 'whole', 'clear', 'dry',
    'easy', 'cold', 'commercial', 'full', 'low', 'primary', 'worth',
    'necessary', 'positive', 'present', 'close', 'creative', 'green', 'late',
    'fit', 'glad', 'proper', 'complex', 'content', 'due', 'effective', 'middle',
    'regular', 'fast', 'independent', 'original', 'wide', 'beautiful',
    'complete', 'active', 'negative', 'safe', 'visual', 'wrong', 'ago', 'quick',
    'ready', 'straight', 'white', 'direct', 'excellent', 'extra', 'junior',
    'pretty', 'unique', 'classic', 'final', 'overall', 'private', 'separate',
    'western', 'alone', 'familiar', 'official', 'perfect', 'bright', 'broad',
    'comfortable', 'flat', 'rich', 'warm', 'young', 'heavy', 'valuable',
    'correct', 'leading', 'slow', 'clean', 'fresh', 'normal', 'secret', 'tough',
    'brown', 'cheap', 'deep', 'objective', 'secure', 'thin', 'chemical', 'cool',
    'extreme', 'exact', 'fair', 'fine', 'formal', 'opposite', 'remote', 'total',
    'vast', 'lost', 'smooth', 'dark', 'double', 'equal', 'firm', 'frequent',
    'internal', 'sensitive', 'constant', 'minor', 'previous', 'raw', 'soft',
    'solid', 'weird', 'amazing', 'annual', 'busy', 'dead', 'false', 'round',
    'sharp', 'thick', 'wise', 'equivalent', 'initial', 'narrow', 'nearby',
    'proud', 'spiritual', 'wild', 'adult', 'apart', 'brief', 'crazy', 'prior',
    'rough', 'sad', 'sick', 'strange', 'external', 'illegal', 'loud', 'mobile',
    'nasty', 'ordinary', 'royal', 'senior', 'super', 'tight', 'upper', 'yellow',
    'dependent', 'funny', 'gross', 'ill', 'spare', 'sweet', 'upstairs', 'usual',
    'brave', 'calm', 'dirty', 'downtown', 'grand', 'honest', 'loose', 'male',
    'quiet', 'brilliant', 'dear', 'drunk', 'empty', 'female', 'inevitable',
    'neat', 'ok', 'representative', 'silly', 'slight', 'smart', 'stupid',
    'temporary', 'weekly', 'that', 'this', 'what', 'which', 'time', 'these',
    'work', 'no', 'only', 'then', 'first', 'money', 'over', 'business', 'his',
    'game', 'think', 'after', 'life', 'day', 'home', 'economy', 'away',
    'either', 'fat', 'key', 'training', 'top', 'level', 'far', 'fun', 'house',
    'kind', 'future', 'action', 'live', 'period', 'subject', 'mean', 'stock',
    'chance', 'beginning', 'upset', 'chicken', 'head', 'material', 'salt',
    'car', 'appropriate', 'inside', 'outside', 'standard', 'medium', 'choice',
    'north', 'square', 'born', 'capital', 'shot', 'front', 'living', 'plastic',
    'express', 'feeling', 'otherwise', 'plus', 'savings', 'animal', 'budget',
    'minute', 'character', 'maximum', 'novel', 'plenty', 'select', 'background',
    'forward', 'glass', 'joint', 'master', 'red', 'vegetable', 'ideal',
    'kitchen', 'mother', 'party', 'relative', 'signal', 'street', 'connect',
    'minimum', 'sea', 'south', 'status', 'daughter', 'hour', 'trick',
    'afternoon', 'gold', 'mission', 'agent', 'corner', 'east', 'neither',
    'parking', 'routine', 'swimming', 'winter', 'airline', 'designer', 'dress',
    'emergency', 'evening', 'extension', 'holiday', 'horror', 'mountain',
    'patient', 'proof', 'west', 'wine', 'expert', 'native', 'opening', 'silver',
    'waste', 'plane', 'leather', 'purple', 'specialist', 'bitter', 'incident',
    'motor', 'pretend', 'prize', 'resident',
]

# Nouns Docker uses to generate container names
nouns = [
    'albattani', 'allen', 'almeida', 'agnesi', 'archimedes', 'ardinghelli',
    'aryabhata', 'austin', 'babbage', 'banach', 'bardeen', 'bartik', 'bassi',
    'beaver', 'bell', 'bhabha', 'bhaskara', 'blackwell', 'bohr', 'booth',
    'borg', 'bose', 'boyd', 'brahmagupta', 'brattain', 'brown', 'carson',
    'chandrasekhar', 'shannon', 'clarke', 'colden', 'cori', 'cray', 'curran',
    'curie', 'darwin', 'davinci', 'dijkstra', 'dubinsky', 'easley', 'edison',
    'einstein', 'elion', 'engelbart', 'euclid', 'euler', 'fermat', 'fermi',
    'feynman', 'franklin', 'galileo', 'gates', 'goldberg', 'goldstine',
    'goldwasser', 'golick', 'goodall', 'haibt', 'hamilton', 'hawking',
    'heisenberg', 'heyrovsky', 'hodgkin', 'hoover', 'hopper', 'hugle',
    'hypatia', 'jang', 'jennings', 'jepsen', 'joliot', 'jones', 'kalam', 'kare',
    'keller', 'khorana', 'kilby', 'kirch', 'knuth', 'kowalevski', 'lalande',
    'lamarr', 'lamport', 'leakey', 'leavitt', 'lewin', 'lichterman', 'liskov',
    'lovelace', 'lumiere', 'mahavira', 'mayer', 'mccarthy', 'mcclintock',
    'mclean', 'mcnulty', 'meitner', 'meninsky', 'mestorf', 'minsky',
    'mirzakhani', 'morse', 'murdock', 'newton', 'nightingale', 'nobel',
    'noether', 'northcutt', 'noyce', 'panini', 'pare', 'pasteur', 'payne',
    'perlman', 'pike', 'poincare', 'poitras', 'ptolemy', 'raman', 'ramanujan',
    'ride', 'montalcini', 'ritchie', 'roentgen', 'rosalind', 'saha', 'sammet',
    'shaw', 'shirley', 'shockley', 'sinoussi', 'snyder', 'spence', 'stallman',
    'stonebraker', 'swanson', 'swartz', 'swirles', 'tesla', 'thompson',
    'torvalds', 'turing', 'varahamihira', 'visvesvaraya', 'volhard', 'wescoff',
    'wiles', 'williams', 'wilson', 'wing', 'wozniak', 'wright', 'yalow',
    'yonath',
]

def _parse_args(args=None):
    """
    Parses command line arguments.
    """

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dir', default='.', nargs='?',
        help='Destination directory for all the files.'
        )
    parser.add_argument('--name-seed',
        default=0,
        help='The random seed to use for generating names.')
    parser.add_argument('--structure-seed',
        default=None,
        help='The random seed to use for generating the structure of the graph.')
    parser.add_argument('--content-seed',
        default=0,
        help='The random seed to use for generating the content of the files.')
    parser.add_argument('--max-width', type=int,
        default=5,
        help='Maximum width of the graph'
        )
    return parser.parse_args(args)

def random_string(random, length=16):
    return ''.join(
        random.choice(string.ascii_lowercase + string.digits)
        for _ in range(length)
        )

def name_generator(random):
    """
    Generates a deterministic list of names for files.
    """
    while True:
        yield '{}_{}'.format(random.choice(adjectives), random.choice(nouns))

def generate_rule(names):
    inputs = [next(names), next(names)]
    outputs = [next(names)]
    task = ["sh", "-c", ' '.join(["cat", *inputs, ">", outputs[0]])]
    return {'inputs': inputs, 'task': [task], 'outputs': outputs}

def independent_rules(n, names):
    """
    Generates a list of rules with no direct dependencies between them.
    """
    while n > 0:
        yield generate_rule(names)
        n -= 1

def combine_rules(rules, names):
    """
    Combines 1 or more rules to create a third.
    """
    inputs = list(itertools.chain(*(r['outputs'] for r in rules)))
    outputs = [next(names)]
    task = ["sh", "-c", ' '.join(["cat", *inputs, ">", outputs[0]])]
    return {'inputs': inputs, 'task': [task], 'outputs': outputs}

def generate_rules(random, queue, names):
    """
    Yields a list of rules for the build description based on the given rules.
    """

    while len(queue) >= 2:
        # Take a random number of rules from the queue
        rules = [queue.pop() for _ in range(min(random.randint(2,3), len(queue)))]

        r = combine_rules(rules, names)
        queue.append(r)
        random.shuffle(queue)
        yield r

if __name__ == '__main__':

    args = _parse_args()

    # The name generator needs a separate random number generator with a fixed
    # seed. If we don't do this and we generate new names every time, we will be
    # creating a new set of files for every build, wasting space.
    names = name_generator(Random(args.name_seed))

    # Top level rules. We generate these first so we can create the input files.
    # The rest of the graph is generated as random combinations of these rules.
    top_level = list(independent_rules(args.max_width, names))

    build = list(generate_rules(
        random=Random(args.structure_seed),
        queue=list(top_level),
        names=names
        ))

    os.makedirs(args.dir, exist_ok=True)

    with open(os.path.join(args.dir, 'button.json'), 'w') as f:
        json.dump(top_level + build, f, indent=4)

    random_content = Random(args.content_seed)

    # Create top-level files
    input_files = itertools.chain(*(r['inputs'] for r in top_level))
    for filename in input_files:
        with open(os.path.join(args.dir, filename), 'w') as f:
            f.write(random_string(random_content, 64))
