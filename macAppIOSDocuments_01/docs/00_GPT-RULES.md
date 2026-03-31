#GPT-RULES v2.3 HYBRID

##STRUCT
src/core=main-logic
src/modules=independent(can-remove-without-break)
src/shared=common-components
src/config=settings
src/utils=helpers
tests=required
docs=documentation
logs=gpt-optimized-logs

##NAMING
class/component=PascalCase
  YES: UserProfile, ProductCard
  NO: userProfile, product_card
func/method=camelCase
  YES: calculateTotal, fetchData
  NO: CalculateTotal, fetch_data
bool=is/has/should+camelCase
  YES: isLoading, hasAccess, shouldUpdate
  NO: loading, access, update
const=UPPER_SNAKE_CASE
  YES: MAX_ITEMS, API_URL
  NO: maxItems, apiUrl
var=camelCase
  YES: userName, productList

##FUNC (CRITICAL)
max-lines=50
max-params=4
if-params>4=use-object
1-func=1-task
name=describes-action

GOOD-EXAMPLE:
```javascript
const calculateDiscount = (price, percent) => {
  return price * (percent / 100);
};

const processOrder = ({ orderId, userId, items }) => {
  // destructuring instead of many params
  validateOrder(orderId);
  return createOrder(userId, items);
};

const fetchUserData = async (userId) => {
  try {
    const response = await api.get(`/users/${userId}`);
    return response.data;
  } catch (error) {
    log(error, 'api.get(`/users/${userId}`)', { userId });
    throw error;
  }
};
```

BAD-EXAMPLE:
```javascript
const calc = (p, d, x, y, z, a, b) => {
  // 200 lines of code
  // does 10 different things
  // no error handling
  // magic numbers everywhere
};
```

##ERR (CRITICAL)
PATTERN: try + catch + log() + throw
NEVER: empty catch, console.log, logger.error without context

GOOD-EXAMPLE:
```javascript
import { log } from './utils/logger';

const fetchData = async (endpoint, userId) => {
  try {
    const response = await api.get(endpoint);
    return response.data;
  } catch (error) {
    // log() creates: {f:"file:line", e:"msg", c:"code", ctx:"vars"}
    log(error, 'const response = await api.get(endpoint)', {
      endpoint,
      userId,
      timestamp: Date.now()
    });
    throw error; // always re-throw after logging
  }
};
```

BAD-EXAMPLES:
```javascript
// BAD: empty catch
try { await fetch(); } catch(e) { }

// BAD: console.log loses context
try { await fetch(); } catch(e) { console.log(e); }

// BAD: no code context
try { await fetch(); } catch(e) { logger.error(e); }

// BAD: catch without throw
try { await fetch(); } catch(e) { log(e, 'code', {}); }
// missing: throw error;
```

##LOG-FORMAT (CRITICAL)
OUTPUT: {f:"file:line", e:"error-msg", c:"code-line", ctx:"var=val"}
FUNCTION: log(error, 'code-that-failed', {variables})

EXAMPLE-OUTPUT:
```json
{
  "f": "UserService.ts:45",
  "e": "TypeError: Cannot read property 'id' of undefined",
  "c": "const id = user.profile.id",
  "ctx": "user.profile=undefined"
}
```

USAGE:
```javascript
// Import
import { log } from './utils/logger';

// In catch block
catch (error) {
  log(error, 'const id = user.profile.id', {
    'user': user,
    'user.profile': user?.profile
  });
  throw error;
}
```

WHY-THIS-FORMAT:
- f=file:line -> GPT knows WHERE
- e=error -> GPT knows WHAT
- c=code -> GPT knows WHICH LINE
- ctx=context -> GPT knows WHY (undefined, null, NaN)
- ~50 tokens per log (90% less than verbose logs)
- 95% GPT accuracy in fixing

##CONST
extract-all-magic-numbers-to-constants
YES:
  const MAX_RETRY = 3;
  const TIMEOUT_MS = 5000;
  if (attempts > MAX_RETRY) retry();
NO:
  if (attempts > 3) retry();
  setTimeout(fn, 5000);

##COMMENTS
write-WHY-not-WHAT
YES: // rate-limit 1req/sec, so we delay
NO: // add two numbers
DELETE: all commented-out code (use git history)

##DOCS
create-file-not-chat
if-content>50-lines=must-be-file
structure: docs/00_GPT-RULES.md, 01_GPT-LOGGER.md, 02_GPT-MODULAR.md
prefix-number=read-priority (00 first, then 01, then 02)

##MD-FORMAT (CRITICAL)
when-creating-any-md-file=use-this-compact-format

NAMING:
  pattern: XX_NAME.md
  XX = priority number (03, 04, 05...)
  NAME = UPPERCASE with hyphens
  YES: 03_API-SPEC.md, 04_DATABASE.md, 05_AUTH-FLOW.md
  NO: api.md, API Spec.md, apiSpec.md

STRUCTURE:
  #TITLE vX.X
  ##SECTION
  key=value
  list: item1, item2, item3
  YES: good-example
  NO: bad-example
  ```code-block-when-needed```

RULES:
  NO: emojis, markdown-tables, long-paragraphs, repeated-explanations
  YES: key=value, YES/NO-examples, compact-lists, code-blocks-for-code-only
  code-blocks: ONLY for actual code/config, NOT for text
  max-line-length: ~80 chars (wrap if longer)

FULL-EXAMPLE (03_API-SPEC.md):
```markdown
#API-SPEC v1.0

##OVERVIEW
base-url=/api/v1
auth=Bearer JWT
content-type=application/json

##ENDPOINTS

###GET /users
desc=get all users
auth=required
query: limit(int,default=20), offset(int,default=0), sort(string)
response: {success:bool, data:User[], total:int}
errors: 401=unauthorized, 500=server

###POST /users
desc=create user
auth=required(admin)
body: {name:string(required), email:string(required), role:string}
response: {success:bool, data:User, message:string}
errors: 400=validation, 401=unauthorized, 409=duplicate-email

###GET /users/:id
desc=get user by id
auth=required
params: id(string,required)
response: {success:bool, data:User}
errors: 401=unauthorized, 404=not-found

##MODELS

###User
id: string (uuid)
name: string (3-50 chars)
email: string (unique, valid-email)
role: string (user|admin|moderator)
createdAt: datetime
updatedAt: datetime

##ERROR-FORMAT
{success:false, message:string, errors:[string]}

##NOTES
rate-limit=100req/min
pagination=cursor-based-for-large-datasets
```

WHY-THIS-FORMAT:
- GPT reads faster (structured)
- tokens reduced ~60%
- human can still understand
- consistent across all docs

##FRONTEND (CRITICAL)
CSS: use clamp(), min(), rem (not px), mobile-first

REACT-COMPONENT-TEMPLATE:
```javascript
import React, { useState, useEffect, useContext, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppContext } from '../context';
import { API_URL } from '../config';
import './Component.css';

const Component = ({ title, onAction }) => {
  // 1. Context
  const { user } = useContext(AppContext);
  
  // 2. State
  const [isLoading, setIsLoading] = useState(false);
  const [data, setData] = useState(null);
  
  // 3. Refs
  const inputRef = useRef(null);
  
  // 4. Effects
  useEffect(() => {
    loadData();
  }, []);
  
  // 5. Handlers
  const handleClick = async () => {
    try {
      setIsLoading(true);
      await onAction();
    } catch (error) {
      log(error, 'await onAction()', { title });
      throw error;
    } finally {
      setIsLoading(false);
    }
  };
  
  // 6. Early returns
  if (isLoading) return <div>Loading...</div>;
  if (!data) return <div>No data</div>;
  
  // 7. Main render
  return (
    <div className="component">
      <h1>{title}</h1>
    </div>
  );
};

export default Component;
```

IMPORT-ORDER: react, router, libs, components, utils, context, constants, styles(LAST)

##BACKEND
API-response: {success:bool, data:obj, message:str, errors:[]}
VALIDATE: always before save
SECURITY: bcrypt.hash(pwd,10), jwt.sign(data,env.SECRET), no-hardcode
ASYNC: always try-catch with log()

##DB
ALWAYS: .select('fields'), .limit(n), .sort()
NO: Model.find() without limit
INDEX: frequent query fields

##FORBIDDEN
console.log() -> log()
console.error() -> log()
var -> const/let
eval() -> NEVER
magic-numbers -> const
secrets-in-code -> .env
inline-styles -> CSS
empty-catch -> log+throw
md-in-chat -> create file

##REQUIRED
log(error, code, vars) for all errors
const/let (never var)
try-catch-log-throw pattern
constants for all numbers
secrets in .env only

##TEST
pattern: describe -> it -> expect
structure: Arrange -> Act -> Assert
coverage: minimum 80%

##PRIORITY
1.security > 2.readability > 3.modularity > 4.error-handling > 5.performance

##LANG-ADAPT
JS/TS: examples above
Python: snake_case func, PascalCase class
Java/C#: PascalCase class, camelCase method
Rust: snake_case func, PascalCase struct
LOG-FORMAT {f,e,c,ctx} = universal ALL languages

##GPT-EXEC
1.read this file
2.read 01_GPT-LOGGER.md
3.read 02_GPT-MODULAR.md
4.follow all rules
5.use log(error,code,vars) - NEVER console
6.validate data
7.modular code
IF-conflict = ASK user
