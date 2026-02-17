# -*- coding: utf-8 -*-
"""
Created on Fri Dec  3 17:20:55 2021

@author: jmatt
"""

import getpass

pwd = getpass.getpass('Enter password: ')

guess = None
while guess != 'e':
    if guess == None:
        guess = getpass.getpass('Enter guess (e for exit): ')
    else:
        if guess == pwd:
            guess = getpass.getpass('\rCorrect!!! Try again? (e for exit): ')
        else:
            guess = getpass.getpass('\rWRONG!!!!! You entered "{}". Try again? (e for exit): '.format(guess))
