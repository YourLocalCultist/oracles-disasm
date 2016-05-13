#!/usr/bin/python2

# This is the program which parses text.txt. Some commands:
#
# \call(XX):
#   Similar to Jump, but it returns to the current text when it's done.
#   There are special values that will cause this to read the text index from
#   RAM at wTextSubstitutions. The values are:
#     \call($ff): Uses [wTextSubstitutions] as the text index.
#     \call($fe): Uses [wTextSubstitutions+1] as the text index.
#     \call($fd): Uses [wTextSubstitutions+2] as the text index.
#     \call($fc): Uses [wTextSubstitutions+3] as the text index.
# \charsfx(XX):
#   Change the sound effect that's played when each character is displayed.
# \cmd8(XX):
#   Displays another textbox when the current one is finished, depending on...
#   things. This is used sparingly, in shops.
# \col(XX):
#   Change to color XX. If XX is $80 or above, the value is written directly
#   to the "attribute byte" in vram.
# \heartpiece:
#   Show the heart icon that pops up when you get a heart piece.
# \item(XX):
#   Displays character "X" from gfx_font_tradeitems.bin.
# \jump(XX):
#   Jump to the given text index. This only works if the high byte of the index you're
#   jumping to is the same as the one you're jumping from.
#   For example, you can't jump from TX_3500 to TX_3600, but TX_3601->TX_3650 is fine.
# \kidname:
#   Name of Bipin & Blossom's child.
# \Link or \link:
#   Player name>
# \number:
#   Display the bcd (binary-coded decimal) number at "wTextNumberSubstution".
#   The value is 2 bytes long, little-endian.
# \num2:
#   Like \number, but uses the value starting 2 bytes after wTextNumberSubstitution.
#   The actual game doesn't use this.
# \opt:
#   Mark the position of an available option in those "yes/no" prompts.
# \pos(XX): (0 <= XX <= 3)
#   Set the position of the textbox.
#   This must be the first command in the text, or it might not work.
# \secret1, \secret2:
#   Display the secret at "w7SecretBuffer1" or "w7SecretBuffer2".
# \speed(XX): (0 <= XX <=3)
#   Change the speed of the text, relative to the selected text speed.
#   The actual game doesn't use this.
# \slow:
#   Disable fast-forwarding to the end of a line for a certain amount of time.
#   The game uses this when you get an essence.
# \stop:
#   Stop the text and wait for input before continuing. The textbox gets wiped
#   when you continue.
# \sym(XX):
#   Displays character "X" from gfx_font_jp.bin. Most of these are kanji.
# \wait(XX):
#   When the textbox is finished, wait for XX frames and then close the textbox automatically.
#   The actual game doesn't use this.
# 
# The following symbols are also understood:
#   \circle
#   \club
#   \diamond
#   \spade
#   \heart
#   \triangle
#   \rectangle
#   \up
#   \down
#   \left
#   \right
#   \abtn
#   \bbtn
#
# You can also insert arbitrary bytes. For example, \abtn is equivalent to:
#   \b8\b9

import sys
import StringIO

index = sys.argv[0].find('/')
if index == -1:
    directory = ''
else:
    directory = sys.argv[0][:index+1]
execfile(directory+'common.py')

if len(sys.argv) < 6:
    print 'Usage: ' + sys.argv[0] + ' dictfile textfile outfile startaddress textoffsetsplitindex [--vwf]'
    print 'dictfile: The dictionary file to use for compression.'
    print 'textfile: a file such as the kind generated by dumpText.py.'
    print 'outfile: an assembly file to be created for WLA containing the final data in a human-unreadable form.'
    print 'startaddress: beginning address to place the text (text table starts here, then the text itself)'
    print 'textoffsetsplitindex: High byte of index at which text will be offset relative to a different address, to accomodate more that 0x10000 bytes of text.'
    sys.exit()

argIndex = 1

dictFile = open(sys.argv[argIndex], 'r')
argIndex+=1
textFile = open(sys.argv[argIndex], 'r')
argIndex+=1
outFilename = sys.argv[argIndex]
argIndex+=1
startAddress = int(sys.argv[argIndex])
argIndex+=1
textOffsetSplitIndex = int(sys.argv[argIndex])
argIndex+=1

useVwf = False

while len(sys.argv) > argIndex:
    s = sys.argv[argIndex]
    argIndex+=1
    if s == '--vwf':
        useVwf = True



class TextStruct:

    def __init__(self, i):
        self.index = i
        self.data = bytearray()
        self.name = 'TX_' + myhex(i-0x400, 4)
        self.ref = None

        # List of tuples (index,name,line), where:
        #  "index" is an index for "data".
        #  "name" is a string which can be evaluated to a byte to be written there.
        #  "line" is the line the data is on for debugging purposes.
        self.unparsedNames = []


class GroupStruct:

    def __init__(self, i):
        self.index = i
        self.textStructs = []
        for x in xrange(0, 256):
            self.textStructs.append(TextStruct((self.index<<8) | x))
        self.lastTextIndex = 0


class DictEntry:

    def __init__(self, i, s):
        self.index = i
        self.string = s


class EntryStruct:

    def __init__(self, d, a, b):
        self.dictEntry = d
        self.i = a
        self.j = b
# Maps string to DictEntry
textDictionary = {}

# Attempt to match the game's compression algorithm (epic failure)
def compressTextMatchGame(text, i):
    j = 0
    res = bytearray()
    dicts = []
    while j < len(text):
        dictEntry = None
        # Attempt to find the largest dictionary entry starting at j
        for k in xrange(len(text), j, -1):
            dictEntry = textDictionary.get(bytes(text[j:k]))
            if dictEntry is not None:
                dicts.append(EntryStruct(dictEntry, j, k))
                break

        j+=1

    dicts = sorted(dicts, key=lambda x: x.j-x.i)

    i = 0
    while i < len(dicts):
        j = i+1
        while j < len(dicts):
            e1 = dicts[i]
            e2 = dicts[j]
            if e1.j > e2.i and e2.j > e1.i:
                dicts.remove(e1)
                i-=1
                break
            j+=1
        i+=1

    res = bytearray()
    i = 0
    while i < len(text):
        entry = None
        for e in dicts:
            if e.i == i:
                entry = e
                break
        if entry is not None:
            res.append((e.dictEntry.index>>8)+2)
            res.append(e.dictEntry.index&0xff)
            i = e.j
        else:
            res.append(text[i])
            i+=1

    return res

# These are the compression functions that are actually used

sys.setrecursionlimit(10000)
memo = {}

def compressTextMemoised(text, i):
    key=text[0:i]
    if key in memo:
        return memo[key]
    res = compressTextOptimal(text, i)
    memo[key] = res
    return res
# Compress first i characters of text

def compressTextOptimal(text, i):
    if i == 0:
        return bytearray()
    elif i == 1:
        b = bytearray()
        b.append(text[0])
        return b

    ret = bytearray(compressTextMemoised(text[:i-1], i-1))
    ret.append(text[i-1])

    j = 0
    get = textDictionary.get
    skip = False
    for c in text:
        if skip:
            j+=1
            skip = False
            continue
        dictEntry = get(text[j:])
        if dictEntry is not None:
            #print 'dictentry'
            res = compressTextMemoised(text[:j], j)
            if len(res)+2 < len(ret):
                res = bytearray(res)
                res.append(((dictEntry.index)>>8)+2)
                res.append(dictEntry.index&0xff)
                ret = res

        # Control codes can't have their parameters compressed
        c = ord(c)
        if c >= 6 and c < 0x10:
            skip = True
        j+=1

    return ret

# This class used as a way to pass around variables in the parseTextFile
# function
class TextState:
    def __init__(self):
        # Normally the initial value would be zero, but after messing around
        # with the palettes, it's equivalent to 4. 0 and 4 are both white color
        # text, but they use different palettes for reasons.
        self.currentColor = 4
        # Number of pixel the line takes up so far
        self.lineWidth = 0
        self.widthUpToLastSpace = 0
        # Index of where to insert a newline if the current line
        # overflows
        self.lastSpaceIndex = 0


# vwf stuff
if useVwf:
    spacingFile = open('text/spacing.bin', 'rb')
    characterSpacing = bytearray(spacingFile.read())
    spacingFile.close()
else:
    characterSpacing = bytearray()
    for i in range(256):
        characterSpacing.append(8)

MAX_LINE_WIDTH = 16*8


textList = []

# Turns a name into an index.
# Note that this ANDs the index with 0xff. I haven't had a need for the upper byte yet.
def parseName(s, neededHighIndex):
    for group in textList:
        for textStruct in group.textStructs:
            if textStruct.name == s:
                if textStruct.index>>8 != neededHighIndex:
                    raise ValueError
                return textStruct.index&0xff
    raise ValueError

def parseTextFile(textFile, isDictionary):
    global textList

    if isDictionary:
        textGroup = GroupStruct(0)
        index = 0x0000
    else:
        textGroup = GroupStruct(4)
        index = 0x0400

    eof = False
    lineIndex = 0
    # Parse text file
    while not eof:
        textStruct = textGroup.textStructs[index&0xff]
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
                    state = TextState()

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

                    def addWidth(state, w):
                        state.lineWidth += w
                        if state.lineWidth >= MAX_LINE_WIDTH:
                            if state.lastSpaceIndex != 0:
                                textStruct.data[state.lastSpaceIndex] = 0x01
                                state.lastSpaceIndex = 0
                                state.lineWidth -= state.widthUpToLastSpace

                    i = 0
                    while i < len(line):
                        c = line[i]
                        if c == '\n':
                            textStruct.data.append(0x01)
                            state.lineWidth = 0
                            state.lastSpaceIndex = 0
                            i+=1
                        elif c == '\\':
                            i+=1

                            validToken = False

                            # Check values which don't need to use brackets
                            if line[i:i+4] == 'Link' or line[i:i+4] == 'link':
                                validToken = True
                                textStruct.data.append(0x0a)
                                textStruct.data.append(0x00)
                                addWidth(state, 8*5)
                                i += 4
                            elif line[i:i+7] == 'kidname':
                                validToken = True
                                textStruct.data.append(0x0a)
                                textStruct.data.append(0x01)
                                addWidth(state, 8*5)
                                i += 7
                            elif line[i:i+7] == 'secret1':
                                validToken = True
                                textStruct.data.append(0x0a)
                                textStruct.data.append(0x02)
                                addWidth(state, 8*5)
                                i += 7
                            elif line[i:i+7] == 'secret2':
                                validToken = True
                                textStruct.data.append(0x0a)
                                textStruct.data.append(0x03)
                                addWidth(state, 8*5)
                                i += 7
                            elif line[i:i+6] == 'number':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(1<<3)
                                addWidth(state, 8*3)
                                i+=6
                            elif line[i:i+3] == 'opt':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(2<<3)
                                addWidth(state, 8)
                                i+=3
                            elif line[i:i+4] == 'stop':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(3<<3)
                                i+=4
                            elif line[i:i+10] == 'heartpiece':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(5<<3)
                                addWidth(state, 16)
                                i+=10
                            elif line[i:i+4] == 'num2':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(6<<3)
                                addWidth(state, 8*3)
                                i+=4
                            elif line[i:i+4] == 'slow':
                                validToken = True
                                textStruct.data.append(0x0c)
                                textStruct.data.append(7<<3)
                                i+=4
                            elif line[i:i+6] == 'circle':
                                validToken = True
                                c = 0x10
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=6
                            elif line[i:i+4] == 'club':
                                validToken = True
                                c = 0x11
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=4
                            elif line[i:i+7] == 'diamond':
                                validToken = True
                                c = 0x12
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=7
                            elif line[i:i+5] == 'spade':
                                validToken = True
                                c = 0x13
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=5
                            elif line[i:i+5] == 'heart':
                                validToken = True
                                c = 0x14

                                if useVwf:
                                    # vwf stuff: the heart is always supposed to be
                                    # red. Since I messed with the palettes this
                                    # needs to be fixed
                                    if state.currentColor >= 2:
                                        textStruct.data.append(0x09)
                                        textStruct.data.append(0x00)
                                        state.currentColor = 0x00

                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=5
                            elif line[i:i+2] == 'up':
                                validToken = True
                                c = 0x15
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=2
                            elif line[i:i+4] == 'down':
                                validToken = True
                                c = 0x16
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=4
                            elif line[i:i+4] == 'left':
                                validToken = True
                                c = 0x17
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=4
                            elif line[i:i+5] == 'right':
                                validToken = True
                                c = 0x18
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=5
                            elif line[i:i+4] == 'abtn':
                                validToken = True
                                c = 0xb8
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                c = 0xb9
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=4
                            elif line[i:i+4] == 'bbtn':
                                validToken = True
                                textStruct.data.append(0xba)
                                textStruct.data.append(0xbb)
                                addWidth(state, characterSpacing[0xba]+characterSpacing[0xbb])
                                i+=4
                            elif line[i:i+8] == 'triangle':
                                validToken = True
                                c = 0x7e
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=8
                            elif line[i:i+9] == 'rectangle':
                                validToken = True
                                c = 0x7f
                                textStruct.data.append(c)
                                addWidth(state, characterSpacing[c])
                                i+=9
                            elif line[i] == '\\':  # 2 backslashes
                                validToken = True
                                textStruct.data.append('\\')
                                addWidth(state, characterSpacing[ord('\\')])
                                i+=1

                            if validToken:
                                try:
                                    if line[i] == '(' and line[i+1] == ')':
                                        i+=2
                                except exceptions.IndexError:
                                    pass
                                continue

                            x = str.find(line, '(', i)
                            token = ''
                            param = -1

                            if x != -1:
                                y = str.find(line, ')', i)
                                if y != -1:
                                    token = line[i:x]
                                    param = line[x+1:y]

                            # Check values which use brackets (tokens)
                            if token == 'item':
                                textStruct.data.append(0x06)
                                textStruct.data.append(parseVal(param) | 0x80)

                                if useVwf:
                                    if state.lineWidth & 7 != 0:
                                        state.lineWidth &= ~7
                                        state.lineWidth += 8
                                    addWidth(state, 8)
                                else:
                                    addWidth(state, 8)
                            elif token == 'sym':
                                textStruct.data.append(0x06)
                                textStruct.data.append(parseVal(param))
                                addWidth(state, 8)
                            elif token == 'jump':
                                textStruct.data.append(0x07)
                                try:
                                    textStruct.data.append(parseVal(param))
                                except ValueError:
                                    textStruct.unparsedNames.append( (len(textStruct.data), param, lineIndex) )
                                    textStruct.data.append(0xff)
                            elif token == 'col':
                                p = parseVal(param)
                                textStruct.data.append(0x09)

                                # Special behaviour for vwf: in order to
                                # prevent colors from "leaking", after using
                                # color 3, it must switch to color 4 for the
                                # normal color instead of color 0
                                if state.currentColor == 3 and p == 0:
                                    p = 4
                                textStruct.data.append(p)
                                state.currentColor = p
                            elif token == 'charsfx':
                                textStruct.data.append(0x0b)
                                textStruct.data.append(parseVal(param))
                            elif token == 'speed':
                                p = parseVal(param)
                                assert(p < 4)
                                textStruct.data.append(0x0c)
                                textStruct.data.append(p)
                            elif token == 'pos':
                                p = parseVal(param)
                                assert(p < 4)
                                textStruct.data.append(0x0c)
                                textStruct.data.append((4<<3) | p)
                            elif token == 'wait':
                                textStruct.data.append(0x0d)
                                textStruct.data.append(parseVal(param))
                            elif token == 'sfx':
                                textStruct.data.append(0x0e)
                                textStruct.data.append(parseVal(param))
                            elif token == 'call':
                                textStruct.data.append(0x0f)
                                try:
                                    textStruct.data.append(parseVal(param))
                                except ValueError:
                                    textStruct.unparsedNames.append( (len(textStruct.data), param, lineIndex) )
                                    textStruct.data.append(0xff)
                            elif len(token) == 4 and\
                                    token[0:3] == 'cmd' and\
                                    isHex(token[3]):
                                textStruct.data.append(int(token[3], 16))
                                textStruct.data.append(parseVal(param))
                            else:
                                textStruct.data.append(int(line[i:i+2], 16))
                                i+=2

                                try:
                                    if line[i] == '(' and line[i+1] == ')':
                                        i+=2
                                except exceptions.IndexError:
                                    pass

                                continue

                            assert(param != -1)
                            i = y+1
                        else:
                            c = line[i]
                            textStruct.data.append(c)

                            if c == ' ':
                                state.lastSpaceIndex = len(textStruct.data)-1
                                state.widthUpToLastSpace = state.lineWidth+characterSpacing[ord(c)]

                            addWidth(state, characterSpacing[ord(c)])

                            i+=1

                elif token == '\\name':
                    textStruct.name = param
                elif token == '\\next':
                    if len(textStruct.data) == 0:
                        textStruct.ref = lastTextStruct
                    else:
                        lastTextStruct = textStruct
                    lastIndex = index
                    if param == -1:
                        index+=1
                    else:
                        index = parseVal(param)
                        if not isDictionary:
                            index += 0x400
                        if index>>8 != lastIndex>>8:
                            textList.append(textGroup)
                            textGroup = GroupStruct(index>>8)
                    textStruct = textGroup.textStructs[index&0xff]
                    if textGroup.lastTextIndex < index&0xff:
                        textGroup.lastTextIndex = index&0xff
                    break
                elif token == '\\nextgroup':
                    if len(textStruct.data) == 0:
                        textStruct.ref = lastTextStruct
                    else:
                        lastTextStruct = textStruct
                    textList.append(textGroup)
                    index = (index&0xff00)+0x100
                    textGroup = GroupStruct(index>>8)
                    textStruct = textGroup.textStructs[index&0xff]
                    if textGroup.lastTextIndex < index&0xff:
                        textGroup.lastTextIndex = index&0xff
            except:
                print 'Error on line ' + str(lineIndex) + ': \"' + line + '\"'
                e = sys.exc_info()
                for l in e:
                    print l
                exit(1)

    if (index&0xff) != 0:
        textList.append(textGroup)

parseTextFile(dictFile, True)
parseTextFile(textFile, False)

# Go through all the TextStructs to deal with the unparsedNames's.
for group in textList:
    for struct in group.textStructs:
        for tup in struct.unparsedNames:
            i = tup[0]
            name = tup[1]
            line = tup[2]
            try:
                struct.data[i] = parseName(name, struct.index>>8)
            except ValueError:
                print 'Error on line ' + str(line) + ': \"' + name + '\" is an invalid name.'
                exit(1)

# Compile dictionary
for i in xrange(4):
    group = textList[i]
    for textStruct in group.textStructs:
        if len(textStruct.data) != 0:
            dat = bytearray(textStruct.data)
            c = dat.pop()  # Remove null terminator
            if c != 0:
                print 'Expected null terminator on dictionary entry ' + hex(textStruct.index)
            textDictionary[bytes(dat)] = DictEntry(textStruct.index, dat)


numGroups = (textList[len(textList)-1].index)+1
# Hardcoded stuff: groups 5e-63 are unused but still have pointers defined
if numGroups < 0x64:
    numGroups = 0x64

# Find 'skipped groups': list of group numbers which are skipped over
skippedGroups = []
i = 0
for group in sorted(textList, key=lambda x: x.index):
    while group.index != i:
        skippedGroups.append(i)
        i+=1
    i+=1
while i < numGroups:
    skippedGroups.append(i)
    i+=1

# Begin generating output
outFile = open(outFilename, 'w')

address = (startAddress%0x4000)+0x4000
bank = startAddress/0x4000

textOffset1 = 'DICT0_00'
textOffset2 = 'TX_' + myhex(textOffsetSplitIndex-4, 2) + '00'

# Print defines

definesFile = open('build/textDefines.s', 'w')

definesFile.write(
    '.DEFINE TEXT_OFFSET_SPLIT_INDEX ' + wlahex(textOffsetSplitIndex, 2) + '\n')

for group in textList:
    if group.index >= 4:
        for textStruct in group.textStructs:
            if textStruct.index&0xff > group.lastTextIndex:
                break
            definesFile.write('.DEFINE ' + textStruct.name + ' ' + wlahex(textStruct.index-0x400) + '\n')

definesFile.close()

# Print tables

outFile.write('.BANK ' + wlahex(bank, 2) + '\n')
outFile.write('.ORGA ' + wlahex(address, 4) + '\n\n')

outFile.write('textTableENG:\n')

for i in xrange(0, numGroups):
    outFile.write('\t.dw textTableENG_' + myhex(i, 2) + ' - textTableENG\n')
    address += 2

# All skipped groups reference group 0
outFile.write('\ntextTableENG_00:\n')
for g in sorted(skippedGroups):
    outFile.write('textTableENG_' + myhex(g, 2) + ':\n')

lastTextName = 'TX_WTFLOL_ADDR'

for group in textList:
    if group.index != 0:
        outFile.write('textTableENG_' + myhex(group.index, 2) + ':\n')

    if group.index < textOffsetSplitIndex:
        textOffset = 'TEXT_OFFSET_1'
    else:
        textOffset = 'TEXT_OFFSET_2'

    for i in xrange(0, group.lastTextIndex+1):
        textStruct = group.textStructs[i]
        if textStruct.ref is None:
            outFile.write(
                '\tm_RelativePointer ' + textStruct.name + '_ADDR  ' + textOffset + '\n')
            address += 2
            i+=1
        else:
            outFile.write(
                '\tm_RelativePointer ' + textStruct.ref.name + '_ADDR  ' + textOffset + '\n')
            address += 2
            i+=1

    while i <= group.lastTextIndex:
        outFile.write(
            '\tm_RelativePointer ' + lastTextName + '  ' + textOffset + '\n')
        address += 2
        i+=1


outFile.write('\n')

# Print actual text
for group in textList:
    for j in xrange(0, group.lastTextIndex+1):
        textStruct = group.textStructs[j]

        if group.index < 4:  # Dictionaries don't get compressed
            data = textStruct.data
        else:  # Everything else does
            data = compressTextMemoised(
                bytes(textStruct.data), len(textStruct.data))

        if textStruct.name == textOffset1:
            outFile.write('TEXT_OFFSET_1:\n')
        elif textStruct.name == textOffset2:
            outFile.write('TEXT_OFFSET_2:\n')

        outFile.write(textStruct.name + '_ADDR:\n')
        i = 0
        lineEntries = 0
        while i < len(data):
            if lineEntries >= 8:
                outFile.write('\n')
                lineEntries = 0
            if lineEntries == 0:
                outFile.write('\t.db')
            outFile.write(' ' + wlahex(data[i], 2))
            i+=1
            lineEntries+=1
            address+=1

            if address >= 0x8000:
                address = 0x4000
                bank += 1
                outFile.write('\n\n.BANK ' + wlahex(bank, 2) + '\n')
                outFile.write('.ORGA ' + wlahex(address, 4) + '\n\n')
                lineEntries = 0

        outFile.write('\n')

        # Debug output
#                 outFile2 = open('build/debug/' + textStruct.name + '.cmp', 'wb')
#                 outFile2.write(data)
#                 outFile2.close()


outFile.write('\n.DEFINE TEXT_END_ADDR ' + wlahex(address, 4) + '\n')
outFile.write('.DEFINE TEXT_END_BANK ' + wlahex(bank, 2))
outFile.close()

# Debug output
# outFile = open('text/test2.bin','wb')
# for i in xrange(4,len(textList)):
#         group = textList[i]
#         for textStruct in group.textStructs:
#                 outFile.write(compressTextMemoised(bytes(textStruct.data), len(textStruct.data)))
# outFile.close()
