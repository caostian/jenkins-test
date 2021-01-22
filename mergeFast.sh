#!/usr/bin/env bash

#获取远程分支
#$1 远程分支名称
function getRemoteBranch() {
    if [ -z "$1" ]
    then
        echo "参数不能为空"
        exit
    fi

    local remoteBranch="remotes/origin/${1}"
    local flag=0
    local allBranch=`git branch -a`

    for v in ${allBranch[*]}
    do
       if [ "$v" = "$remoteBranch" ]
       then
           flag=1
           git checkout -b "$1" "$remoteBranch"
       fi
    done

    if [ "$flag" -eq 0 ]
    then
        echo "分支名称错误, 请确认分支名称"
        exit
    fi
}

#获取本地分支
#$2 合并分支名称
function getLocalBranch() {
    if [ -z "$1" ]
    then
        echo "参数不能为空"
        exit
    fi

    local mergeBranch="$1" # $1你的输入分支, 需要合并的分支
    local flag=0
    local index=0
    local allBranchArr=`git branch | sed 's/*/^/g'` # 把*替换成^
    echo $allBranchArr

    allBranchArr=(${allBranchArr// / })

    echo 
    echo 
    echo $allBranchArr
    for i in ${allBranchArr[*]}
    do
        if [ "$mergeBranch" = "$i" ]
        then
            flag=1
        fi
        if [ "^" = "$i" ]
        then
            currentIndex=`expr ${index} + 1`
        fi
        index=`expr ${index} + 1`
    done
    if [ ${flag} -eq 0 ]
    then
        echo "error"
    fi

    return $currentIndex
}

#合并master分支
#$1 本地分支名称
function mergeMaster() {
    if [ -z "$1" ]
    then
        echo "参数错误"
        exit
    fi

    local localBranch="$1"
    local targetBranch="master"

    checkCurrent

    git checkout ${targetBranch}

    masterRe=`git pull origin ${targetBranch} | grep 'Already up to date'`

    git checkout "$localBranch"

    #有文件更新则合并分支
    if [ -z "$masterRe" ]
    then
        git merge ${targetBranch} -m "merge ${targetBranch} into ${localBranch}"

        gitDiff=`git diff --check`

        if [ -n "$gitDiff" ]
        then
            echo ${gitDiff}
            echo 'master合并到本地冲突，请解决冲突'
            exit
        fi
    fi
}

#开始合并分支
#$1 远程分支名称
#$2 本地分支名称
#$3 是否拉取最新代码
function beginMergeBranch() {
    if [ -z "$1" -o -z "$2" ]
    then
        echo "参数错误"
        exit
    fi

    local mergeBranch="$1"
    local currentBranch="$2"
    echo "开始合并分支: ${currentBranch} into ${mergeBranch}"

    if [ -z "$3" ]
    then
        git checkout ${mergeBranch}

        git pull origin ${mergeBranch}
    fi

    git merge ${currentBranch} -m "merge ${currentBranch} into ${mergeBranch}"

    gitDiff=`git diff --check`

    if [ -n "$gitDiff" ]
    then
        echo ${gitDiff}
        echo '合并遇到冲突，请解决冲突'
        exit
    fi

    echo "提交代码"
    git commit -m "merge ${currentBranch} into ${mergeBranch}"

    echo "推送代码至 $mergeBranch"
    echo `git push origin ${mergeBranch}`

    echo "回到 ${currentBranch} 分支"
    git checkout ${currentBranch}

    git pull origin ${currentBranch}
    git push origin ${currentBranch}
}

#检测当前分支是否有提交
function checkCurrent() {
    gitStatus=`git status | grep 'Changes'`

    if [ -n "$gitStatus" ] # -n 查看当前变量是否被赋值
    then
        echo '请先把当前分支代码提交'
        exit
    fi
}

#cd ~/Users/lc/Documents/project/beginner_api

branchLog=".merge.log"
if [ -z "$1" ] # [ -z STRING ]  “STRING” 的长度为零则为真
then
    if [ ! -s "$branchLog" ] #文件大小非0时为真
    then
        echo "请输入一个分支名: beta/v20201212"
        exit
    fi

    mergeBranch=`cat $branchLog`
    read -t 30 -p "将要合并的分支: ${mergeBranch} , 按y/n 继续: " readConfirm
    if [ "$readConfirm" != "y" ]
    then
        exit
    fi
else
    mergeBranch="$1" # 第一个参数
fi

checkCurrent
echo "主动合并的分支为： ${mergeBranch}"

#获取本地分支名称
localBranchRe=`getLocalBranch "$mergeBranch"`
currentIndex="$?"

allBranch=`git branch | sed 's/*/^/g'`
allBranchArr=(${allBranch// / })
currentBranch=${allBranchArr[${currentIndex}]}

echo "合并master分支到当前分支: ${currentBranch}"
mergeMaster "$currentBranch"

if [ "$localBranchRe" = "error" ]
then
    echo "本地分支不存在,自动拉取远程分支: ${mergeBranch}"
    getRemoteBranch "$mergeBranch"
    beginMergeBranch "$mergeBranch" "$currentBranch" 1
else
    beginMergeBranch "$mergeBranch" "$currentBranch"
fi

echo "$mergeBranch" > "$branchLog"
echo "success"

