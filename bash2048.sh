#!/usr/bin/env bash

#######################################################################
#
#                   2048 게임 in Bash Shell
#
#  @author    Dong-Min Seol
#  @since     2019.05.10
#
#######################################################################

# variables
declare -ia board    
declare -i pieces    # 필드위 블록 개수
declare -i score=0   # 점수
declare -i flag_skip 
declare -i moves     # 움직일 수 있는 블록 방향 체크용 변수 
declare ESC=$'\e'    

declare header="
#######################################################
#                                                     #
#                  BASH로 만든  2048                  #
#                                                     #
#######################################################"

declare -i start_time=$(date +%s)

# 기본 세팅
declare -i board_size=4				      # 보드 사이즈
declare -i target=2048			   	      # 목표 점수
declare -i reload_flag=0                  # 저장된 파일을 읽을 지 여부 ( 0 : false , 1 : true )
declare config_dir="$HOME/kpu2048/saveData"  # 파일 저장 경로

# 숫자별 color 설정
declare -a colors			  # color container array
colors[2]=33                  # 숫자 [2]    : yellow
colors[4]=32                  # 숫자 ]4]    : green
colors[8]=34                  # 숫자 [8]    : blue
colors[16]=36                 # 숫자 [16]   : cyan
colors[32]=35                 # 숫자 [32]   : purple 
colors[64]="33m\033[7"        # 숫자 [64]   : yellow  (background) 
colors[128]="32m\033[7"       # 숫자 [128]  : green   (background) 
colors[256]="34m\033[7"       # 숫자 [256]  : blue    (background) 
colors[512]="36m\033[7"       # 숫자 [512]  : cyan    (background) 
colors[1024]="35m\033[7"      # 숫자 [1024] : purple  (background) 
colors[2048]="31m\033[7"      # 숫자 [2048] : red     (default 승리조건 점수)

trap "end_game 0 1" INT #handle INT signal

################################################################################
#
#    스크립트 실행 시 입력받은 옵션 처리 함수
#
#    @author Dong-Min Seol
#    @since  2019.05.15
#
################################################################################
function _seq {
  local cur=1
  local max
  local inc=1
  case $# in
    1) let max=$1;;
    2) let cur=$1
       let max=$2;;
    3) let cur=$1
       let inc=$2
       let max=$3;;
  esac

  while test $max -ge $cur; do
    printf "$cur "
    let cur+=inc
  done
}

################################################################################
#
#  2048 게임판을 렌더링 해주는 함수,
#  가장 최근에 생성된 숫자는 빨간 텍스트로 표시함 
#
#
#  @author    Dong-Min Seol
#  @since     2015.05.10
#
#################################################################################
function print_board {
  clear # [1] 버퍼 초기화
	  
  printf "$header \n\n  블록수 = $pieces\t목표점수 = $target\t현재점수 = $score"
  printf "\n\n"
  printf '/------'

  for l in $(_seq 1 $index_max); do
    printf '+------'
  done

  printf '\\\n'
  for l in $(_seq 0 $index_max); do

    printf '|'
    
    for m in $(_seq 0 $index_max); do
      if let ${board[l*$board_size+m]}; then
        if let '(last_added==(l*board_size+m))|(first_round==(l*board_size+m))'; then
          printf '\033[1m\033[31m %4d \033[0m|' ${board[l*$board_size+m]}
        else
          printf "\033[1m\033[${colors[${board[l*$board_size+m]}]}m %4d\033[0m |" ${board[l*$board_size+m]}
        fi
      else
        printf '      |'
      fi
    done

    let l==$index_max || {
      printf '\n|------'

      for l in $(_seq 1 $index_max); do
        printf '+------'
      done

      printf '|\n'
    }

  done

  printf '\n\\------'
  for l in $(_seq 1 $index_max); do
    printf '+------'
  done
  printf '/\n'
}

###############################################################################
# 
#                 게임판에 새로운 숫자를 생성하는 함수 
#
#
#  @param    $board   기존 게임판 container
#            $pices   기존 게임판에 존재하는 숫자 블록 개수
#
#  @return   $board   새로 렌더링 한 게임판 container
#            $pices   렌더링 된 게임판에 존재하는 숫자 블록 개수
#
#
#  @author   Dong-Min Seol
#  @since    2015.05.10
#
###############################################################################
function generate_piece {
  while true; do
    let pos=RANDOM%fields_total
    let board[$pos] || {
      let value=RANDOM%10?2:4
      board[$pos]=$value
      last_added=$pos
      break;
    }
  done
  let pieces++
}

###################################################################
#  
#                     두개의 같은 숫자를 합치는 함수
#
# @author Dong-Min Seol
# @since  2019.05.13
####################################################################
function push_pieces {
  case $4 in
    "up")
      let "first=$2*$board_size+$1"
      let "second=($2+$3)*$board_size+$1"
      ;;
    "down")
      let "first=(index_max-$2)*$board_size+$1"
      let "second=(index_max-$2-$3)*$board_size+$1"
      ;;
    "left")
      let "first=$1*$board_size+$2"
      let "second=$1*$board_size+($2+$3)"
      ;;
    "right")
      let "first=$1*$board_size+(index_max-$2)"
      let "second=$1*$board_size+(index_max-$2-$3)"
      ;;
  esac
  let ${board[$first]} || { 
    let ${board[$second]} && {
      if test -z $5; then
        board[$first]=${board[$second]}
        let board[$second]=0
        let change=1
      else
        let moves++
      fi
      return
    }
    return
  }
  let ${board[$second]} && let flag_skip=1
  let "${board[$first]}==${board[second]}" && { 
    if test -z $5; then
      let board[$first]*=2
      let "board[$first]"=="$target" && end_game 1
      let board[$second]=0
      let pieces-=1
      let change=1
      let score+=${board[$first]}
    else
      let moves++
    fi
  }
}

#################################################################
# 
#
#
#
#
#################################################################
function apply_push {
  for i in $(_seq 0 $index_max); do
    
    for j in $(_seq 0 $index_max); do
      flag_skip=0
      let increment_max=index_max-j
      
	  for k in $(_seq 1 $increment_max); do
        let flag_skip && break
        push_pieces $i $j $k $1 $2
      done 

    done
  done
}
#################################################################
#               움직일 공간이 있는지 검증하는 함수 
#   
#
#  @author Dong-Min Seol
#  @since  2019.05.15
#
#################################################################
function check_moves {
  let moves=0
  apply_push up fake
  apply_push down fake
  apply_push left fake
  apply_push right fake
}
##############################################################
#
#                user 키보드 이벤트 반응 함수
#
#    @author Dong-Min Seol
#    @since  2019.05.10
#
##############################################################
function key_react {
  let change=0
  read -d '' -sn 1
  test "$REPLY" = "$ESC" && {
    read -d '' -sn 1 -t1
    test "$REPLY" = "[" && {
      read -d '' -sn 1 -t1
      case $REPLY in
        A) apply_push up;;
        B) apply_push down;;
        C) apply_push right;;
        D) apply_push left;;
      esac
    }
  } || {
    case $REPLY in
      k) apply_push up;;
      j) apply_push down;;
      l) apply_push right;;
      h) apply_push left;;

      w) apply_push up;;
      s) apply_push down;;
      d) apply_push right;;
      a) apply_push left;;
    esac
  }
}

###################################################################
#
#  게임 저장 함수
#
#  @author Dong-Min Seol
#  @since  2019.05.15
#
###################################################################
function save_game {
  
  # [1] 기존 저장 파일 제거
  rm -rf "$config_dir"

  # [2] 저장 폴더 새로 생성 후 저장
  mkdir "$config_dir"
  echo "${board[@]}"  > "$config_dir/board"
  echo "$board_size"  > "$config_dir/board_size"
  echo "$pieces"      > "$config_dir/pieces"
  echo "$target"      > "$config_dir/target"
  echo "$score"       > "$config_dir/score"
  echo "$first_round" > "$config_dir/first_round"
}

###################################################################
#
#  저장된 게임 로딩 함수
#
#  @author Dong-Min Seol
#  @since  2019.05.15
#
###################################################################
function reload_game {

  # [1] 파일 미존재시 함수 종료
  if test ! -d "$config_dir"; then
    return
  fi
  
  # [2] 파일 로딩하기
  board=(`cat "$config_dir/board"`)
  board_size=(`cat "$config_dir/board_size"`)
  board=(`cat "$config_dir/board"`)
  pieces=(`cat "$config_dir/pieces"`)
  first_round=(`cat "$config_dir/first_round"`)
  target=(`cat "$config_dir/target"`)
  score=(`cat "$config_dir/score"`)

  fields_total=board_size*board_size
  index_max=board_size-1
}

######################################################################
#
#   게임 패배시 호출 함수
#
#   @author Dong-Min Seol
#   @since  2019.05.15
#
#######################################################################
function end_game {
  
  end_time=$(date +%s) 
  let total_time=end_time-start_time
  
  print_board
  printf "당신의 점수: $score\n"
  
  printf "게임 플레이 시간"

  `date --version > /dev/null 2>&1`
  if [[ "$?" -eq 0 ]]; then
      date -u -d @${total_time} +%T
  else
      date -u -r ${total_time} +%T
  fi
  
  stty echo # 입력값 안보이게 하기
  
  # 입력값이 참인 경우,
  let $1 && {
    printf "축하합니다 목표점수인 $target 점에 도달하셨습니다."
    exit 0
  }
  
  let test -z $2 && {
    read -n1 -p "게임을 저장하시겠습니까? [Y|N]: "
    
	test "$REPLY" = "Y" || test "$REPLY" = "y" && {
      save_game
      printf "\n게임이 저장되었습니다. 재시작시 -r 옵션을 통해 로드할 수 있습니다.\n"
      exit 0
    }

    test "$REPLY" = "" && {
      printf "\n게임이 저장되지 않았습니다\n"
      exit 0
    }
  }

  printf "\n패배하였습니다.\n"
  exit 0
}

############################################################################
#
#                        유저 사용법 안내  함수
#
#
#   @author Dong-Min Seol
#   @since  2019.05.15
#
############################################################################
function help {
  cat <<END_HELP
사용법 : $1 [-b INTEGER] [-t INTEGER] [-r] [-h]

  -b			게임판의 크기 설정 (사이즈는 3-9 사이만 가능)
  -t			목표 클리어 점수 성정 (2의 제곱인 수만 가능)
  -r			이전에 저장되었던 게임을 로딩합니다.
  -h			이 도움말 창을 표시합니다.

END_HELP
}

############################################################################
#
#                          프로그램 실행 부분 
#
#  @author Domg-Min Seol
#  @since  2019.05.15
#
#############################################################################

# [1] 실행 옵션 설정
while getopts "b:t:rh" opt; do
  case $opt in
    b ) board_size="$OPTARG"
      let '(board_size>=3)&(board_size<=9)' || {
        printf "비정상적인 게임 사이즈입니다 3 ~ 9 사이의 숫자를 입력해 주세요\n"
        exit -1 
      };;
    t ) target="$OPTARG"
      printf "obase=2;$target\n" | bc | grep -e '^1[^1]*$'
      let $? && {
        printf "비정상적인 값입니다 2의 거듭 제곱만 가능합니다.\n"
        exit -1 
      };;
    r ) reload_flag="1";;
    h ) help $0
        exit 0;;
    \?) printf "부적절한 옵션 -"$opt", -h를 사용해보세요 \n" >&2
            exit 1;;
  esac
done

# [2] board init
let fields_total=board_size*board_size
let index_max=board_size-1
for i in $(_seq 0 $fields_total); do board[$i]="0"; done
let pieces=0
generate_piece
first_round=$last_added
generate_piece

# [3] save 파일 존재 시  load
if test $reload_flag = "1"; then
  reload_game
fi

# [4] 게임 실행
while true; do
  print_board
  key_react
  let change && generate_piece
  first_round=-1
  let pieces==fields_total && {
   check_moves
   let moves==0 && end_game 0 # 패배
  }
done

