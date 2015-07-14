#!/usr/bin/python2
import sys
import StringIO

index = sys.argv[0].find('/') 
if index == -1:
	directory = ''
else:
	directory = sys.argv[0][:index+1]
execfile(directory+'common.py')

if len(sys.argv) < 4:
	print 'Usage: ' + sys.argv[0] + ' textfile outfile startaddress'
        print '\ntextfile: a file such as the kind generated by dumpText.py.'
        print 'outfile: an assembly file to be created for WLA containing the final data in a human-unreadable form.'
        print 'startaddress (hex): beginning address to place the text (text table starts here, then the text itself)'
	sys.exit()

textFile = open(sys.argv[1],'r')

class TextStruct:
        def __init__(self, i):
                self.index = i
                self.data = bytearray()
                self.name = 'TX_' + myhex(i-0x400,4)
class GroupStruct:
        def __init__(self, i):
                self.index = i
                self.textStructs = [] # Not necessarily ordered
                self.lastTextIndex = 0
class DictEntry:
        def __init__(self, i, s):
                self.index = i
                self.string = s

# Maps string to DictEntry
textDictionary = {}

memo = {}
# Attempt to match the game's compression algorithm
def compressText(text, i):
        j = 0
        while j < len(text):
                # Attepmt to find the largest dictionary entry starting at j
                for k in xrange(len(text)-1,j,-1):
                        j+=1
                j+=1


# Compress first i characters of text
def compressTextOptimal(text, i):
        m = memo.get(i)
        if m is not None:
                return m
        if i == 0:
                return bytearray()
        elif i == 1:
                b = bytearray()
                b.append(text[0])
                return b
        
        possibilities = []

        res = bytearray(compressTextOptimal(text,i-1))
        res.append(text[i-1])
        possibilities.append(res)

        for j in xrange(0,i-1):
                dictEntry = textDictionary.get(bytes(text[j:i]))
                if dictEntry is not None:
#                        print 'dictentry'
                        res = bytearray(compressTextOptimal(text, j))
                        res.append(((dictEntry.index)>>8)+2)
                        res.append(dictEntry.index&0xff)
                        possibilities.append(res)

        res = possibilities[0]
        for i in xrange(1,len(possibilities)):
                res2 = possibilities[i]
                if len(res2) < len(res):
                        res = res2

        memo[i] = res
        return res

textList = []

textGroup = GroupStruct(0)
index = 0x0000
eof = False
lineIndex = 0
# Parse text file
while not eof:
        textStruct = TextStruct(index)
        started = False
        while True:
                line = textFile.readline()
                lineIndex+=1
                if len(line) == 0:
                        eof = True
                        break
                try:
                        x = str.find(line, '(')
                        if x == -1:
                                token = str.strip(line)
                                param = -1
                        else:
                                token = str.strip(line[0:x])
                                param = line[x+1:str.find(line, ')')]
                        if token == '\\start':
                                started = True
                        elif token == '\\end':
                                started = False
                                c = textStruct.data.pop()
                                if c != 1:
                                        print 'Expected newline at line ' + str(lineIndex)
                                        print 'This is probably a bug'
                                textStruct.data.append(0)
                        elif token == '\\endwithoutnull':
                                textStruct.data.pop()
                                started = False
                        elif started:
                                # After the 'start' directive, text is actually read.
                                i = 0
                                while i < len(line):
                                        c = line[i]
                                        if c == '\n':
                                                textStruct.data.append(chr(1))
                                        elif c == '\\':
                                                i+=1
                                                x = str.find(line,'(',i)
                                                token = line
                                                param = -1
                                                validToken = False
                                                if x != -1:
                                                        y = str.find(line,')',i)
                                                        if y != -1:
                                                                token = line[i:x]
                                                                param = line[x+1:y]
                                                if line[i] == '\\': # 2 backslashes
                                                        textStruct.data.append('\\')
                                                # Check values which don't use brackets
                                                elif line[i:i+4] == 'Link':
                                                        textStruct.data.append(0x0a)
                                                        textStruct.data.append(0x00)
                                                        i += 3
                                                elif line[i:i+7] == 'kidname':
                                                        textStruct.data.append(0x0a)
                                                        textStruct.data.append(0x01)
                                                        i += 6
                                                # Check values which use brackets (tokens)
                                                elif token == 'jump':
                                                        textStruct.data.append(0x07)
                                                        textStruct.data.append(parseVal(param))
                                                        validToken = True
                                                elif token == 'col':
                                                        textStruct.data.append(0x09)
                                                        textStruct.data.append(parseVal(param))
                                                        validToken = True
                                                elif token == 'sfx':
                                                        textStruct.data.append(0x0e)
                                                        textStruct.data.append(parseVal(param))
                                                        validToken = True
                                                elif len(token) == 4 and\
                                                        token[0:3] == 'cmd' and\
                                                        isHex(token[3]):
                                                                textStruct.data.append(int(token[3],16))
                                                                textStruct.data.append(parseVal(param))
                                                                validToken = True
                                                else:
                                                        textStruct.data.append(int(line[i:i+2],16))
                                                        i+=1
                                                if validToken and param != -1:
                                                        x = str.find(line,')',i)
                                                        if x == -1:
                                                                print 'ERROR: Missing closing bracket'
                                                                sys.exit(1)
                                                        i = x
                                        else:
                                                textStruct.data.append(line[i])
                                        i+=1
                        elif token == '\\name':
                                textStruct.name = param
                        elif token == '\\next':
                                if len(textStruct.data) != 0:
                                        textGroup.textStructs.append(textStruct)
                                lastIndex = index
                                if param == -1:
                                        index+=1
                                else:
                                        index = parseVal(param)
                                        if index>>8 != lastIndex>>8:
                                                textList.append(textGroup)
                                                textGroup = GroupStruct(index>>8)
                                textStruct = TextStruct(index)
                                if textGroup.lastTextIndex < index&0xff:
                                        textGroup.lastTextIndex = index&0xff
                                break
                        elif token == '\\nextgroup':
                                if len(textStruct.data) != 0:
                                        textGroup.textStructs.append(textStruct)
                                textList.append(textGroup)
                                index = (index&0xff00)+0x100
                                textGroup = GroupStruct(index>>8)
                                textStruct = TextStruct(index)
                                if textGroup.lastTextIndex < index&0xff:
                                        textGroup.lastTextIndex = index&0xff
                except:
                        print 'Error on line ' + str(lineIndex) + ': \"' + line + '\"'
                        e = sys.exc_info()
                        for l in e:
                                print l
                        exit(1)

if len(textStruct.data) != 0:
        textGroup.textStructs.append(textStruct)
if len(textGroup.textStructs) != 0:
        textList.append(textGroup)
# Done parsing text file

# Compile dictionary
for i in xrange(4):
        group = textList[i]
        for textStruct in group.textStructs:
                dat = bytearray(textStruct.data)
                c = dat.pop() # Remove null terminator
                if c != 0:
                        print 'Expected null terminator on dictionary entry ' + hex(textStruct.index)
                textDictionary[bytes(dat)] = DictEntry(textStruct.index, dat)


numGroups = (textList[len(textList)-1].index)+1
if numGroups < 0x64: # Hardcoded stuff: groups 5e-63 are unused but still have pointers defined
        numGroups = 0x64

# Find 'skipped groups': list of group numbers which are skipped over
skippedGroups = []
i = 0
for group in textList:
        while group.index != i:
                skippedGroups.append(i)
                i+=1
        i+=1
while i < numGroups:
        skippedGroups.append(i)
        i+=1

# Begin generating output
outFile = open(sys.argv[2], 'w')
startAddress = int(sys.argv[3], 16)
address = (startAddress%0x4000)+0x4000
bank = startAddress/0x4000

textOffset1 = 0x75ed8
textOffset2 = 0x8458e

outFile.write('.BANK ' + wlahex(bank,2) + '\n')
outFile.write('.ORGA ' + wlahex(address,4) + '\n\n')

outFile.write('textTableENG:\n')

for i in xrange(0,numGroups):
        outFile.write('\t.dw textTableENG_' + myhex(i,2) + ' - textTableENG\n')
        address += 2

# All skipped groups reference group 0
outFile.write('\ntextTableENG_00:\n')
for g in sorted(skippedGroups):
        outFile.write('textTableENG_' + myhex(g,2) + ':\n')

lastTextName = 'TX_WTFLOL_ADDR'

# Print tables
for group in textList:
        if group.index != 0:
                outFile.write('textTableENG_' + myhex(group.index,2) + ':\n')

        if group < 0x2c:
                textOffset = textOffset1
        else:
                textOffset = textOffset2

        i = 0
        for textStruct in sorted(group.textStructs, key=lambda x:x.index):
                while i != textStruct.index&0xff:
                        outFile.write('\tm_TextPointer ' + lastTextName + ' ' + wlahex(textOffset/0x4000,2) + ' ' +
                                wlahex(textOffset%0x4000,4) + '\n')
                        address += 2
                        i+=1
                lastTextName = textStruct.name + '_ADDR'
                outFile.write('\tm_TextPointer ' + lastTextName + ' ' + wlahex(textOffset/0x4000,2) + ' ' +
                                wlahex(textOffset%0x4000,4) + '\n')
                address += 2
                i+=1

        while i <= group.lastTextIndex:
                outFile.write('\tm_TextPointer ' + lastTextName + ' ' + wlahex(textOffset/0x4000,2) + ' ' +
                        wlahex(textOffset%0x4000,4) + '\n')
                address += 2
                i+=1

        
outFile.write('\n')

# Print actual text
for group in textList:
        for textStruct in group.textStructs:
                if group.index < 4: # Dictionaries don't get compressed
                        data = textStruct.data
                else: # Everything else does
                        memo = {}
                        data = compressTextOptimal(textStruct.data, len(textStruct.data))
                outFile.write(textStruct.name + '_ADDR:\n')
                i = 0
                lineEntries = 0
                while i < len(data):
                        if address >= 0x8000:
                                address = 0x4000
                                bank += 1
                                outFile.write('\n\n.BANK ' + wlahex(bank,2) + '\n')
                                outFile.write('.ORGA ' + wlahex(address,4) + '\n\n')
                                lineEntries = 0
                        if lineEntries >= 8:
                                outFile.write('\n')
                                lineEntries = 0
                        if lineEntries == 0:
                                outFile.write('\t.db')
                        outFile.write(' ' + wlahex(data[i],2))
                        i+=1
                        lineEntries+=1
                        address+=1
                outFile.write('\n')


outFile.write('\n; Ending address: ' + hex(address))
outFile.close()

# Debug output
outFile = open('text/test2.bin','wb')
for i in xrange(4,len(textList)):
        group = textList[i]
        for textStruct in group.textStructs:
                memo = {}
                outFile.write(compressTextOptimal(textStruct.data, len(textStruct.data)))
outFile.close()
